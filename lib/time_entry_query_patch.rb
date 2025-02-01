module RedmineTimeEntriesGroupByIssue
  module TimeEntryQueryPatch
    def self.included(base)
      base.class_eval do
        alias_method :available_columns_without_issue, :available_columns

        def available_columns
          @available_columns ||= begin
                                   cols = available_columns_without_issue

                                   # Добавляем или обновляем колонку issue
                                   issue_column = cols.find { |column| column.name == :issue }
                                   if issue_column
                                     Rails.logger.info "DEBUG: [available_columns] Найдена колонка :issue, обновляем groupable"
                                     issue_column.groupable = "#{TimeEntry.table_name}.issue_id"
                                   else
                                     Rails.logger.info "DEBUG: [available_columns] Колонка :issue не найдена, добавляем новую"
                                     cols << QueryColumn.new(:issue,
                                                             :caption   => :field_issue,
                                                             :groupable => "#{TimeEntry.table_name}.issue_id",
                                                             :sortable  => "#{TimeEntry.table_name}.issue_id")
                                   end

                                   # Делаем колонку hours суммируемой
                                   hours_column = cols.find { |column| column.name == :hours }
                                   if hours_column
                                     Rails.logger.info "DEBUG: [available_columns] Найдена колонка :hours, обновляем totalable"
                                     hours_column.totalable = :sum
                                   else
                                     Rails.logger.info "DEBUG: [available_columns] Колонка :hours не найдена, добавляем новую"
                                     cols << QueryColumn.new(:hours,
                                                             :caption   => :field_hours,
                                                             :totalable => :sum)
                                   end

                                   Rails.logger.info "DEBUG: [available_columns] Итоговый список колонок: #{cols.map(&:name).inspect}"
                                   cols
                                 end
        end

        def group_by_statement
          return nil unless grouped?
          if group_by_column.name == :issue
            Rails.logger.info "DEBUG: [group_by_statement] Группировка по :issue, возвращаем '#{TimeEntry.table_name}.issue_id'"
            return "#{TimeEntry.table_name}.issue_id"
          end
          super
        end

        def total_for_hours(scope)
          result = scope.sum("#{TimeEntry.table_name}.hours").to_f
          Rails.logger.info "DEBUG: [total_for_hours] Сумма часов: #{result} для SQL: #{scope.to_sql}"
          result
        end

        def total_by_group_for(column)
          Rails.logger.info "DEBUG: [total_by_group_for] Вход в метод total_by_group_for для колонки #{column.name}, grouped?=#{grouped?}, group_by_column=#{group_by_column.inspect}"
          return super unless column.name == :hours && grouped? && group_by_column.name == :issue

          result = {}
          grouped_query do |scope|
            Rails.logger.info "DEBUG: [total_by_group_for] В блоке grouped_query. SQL запроса: #{scope.to_sql}"
            result = scope.group("#{TimeEntry.table_name}.issue_id").sum("#{TimeEntry.table_name}.hours")
            Rails.logger.info "DEBUG: [total_by_group_for] Результат группировки (сырые данные): #{result.inspect}"
          end

          # Извлекаем фактические идентификаторы задач: если ключ – массив, берем первый элемент
          issue_ids = result.keys.map { |key| key.is_a?(Array) ? key.first : key }
          issues = Issue.where(id: issue_ids).index_by(&:id)
          Rails.logger.info "DEBUG: [total_by_group_for] Загруженные объекты Issue: #{issues.inspect}"

          transformed_result = result.each_with_object({}) do |(group_key, hours), hash|
            issue_id = group_key.is_a?(Array) ? group_key.first : group_key
            if issues[issue_id]
              hash[issues[issue_id]] = hours.to_f
            else
              Rails.logger.warn "WARN: Issue с id=#{issue_id} не найден"
            end
          end

          Rails.logger.info "DEBUG: [total_by_group_for] Преобразованный результат группировки: #{transformed_result.inspect}"
          transformed_result
        end

        def joins_for_order_statement(order_options = nil)
          joins = []
          if grouped? && group_by_column.name == :issue
            joins << "LEFT OUTER JOIN #{Issue.table_name} ON #{Issue.table_name}.id = #{TimeEntry.table_name}.issue_id"
            Rails.logger.info "DEBUG: [joins_for_order_statement] Добавляем LEFT OUTER JOIN для связи с Issue"
          end

          join_statement = super
          Rails.logger.info "DEBUG: [joins_for_order_statement] Результат вызова super: #{join_statement}"
          joins << join_statement if join_statement
          final_joins = joins.compact.uniq.join(' ')
          Rails.logger.info "DEBUG: [joins_for_order_statement] Итоговое значение joins: #{final_joins}"
          final_joins
        end
      end
    end
  end
end

require_dependency 'time_entry_query'
unless TimeEntryQuery.included_modules.include?(RedmineTimeEntriesGroupByIssue::TimeEntryQueryPatch)
  TimeEntryQuery.send(:include, RedmineTimeEntriesGroupByIssue::TimeEntryQueryPatch)
end