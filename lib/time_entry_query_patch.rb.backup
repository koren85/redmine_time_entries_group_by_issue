module RedmineTimeEntriesGroupByIssue
  # Класс для колонок с вычисляемым значением через Proc.
  class QueryColumnWithProc < QueryColumn
    def initialize(name, options = {})
      super(name, options)
      @value_proc = options[:value]
    end

    # Переопределяем метод value, чтобы использовать переданный Proc,
    # а не пытаться вызвать метод с именем колонки у объекта.
    def value(object)
      if @value_proc.respond_to?(:call)
        @value_proc.call(object, self)
      else
        super(object)
      end
    end

    def value_object(object)
      if @value_proc.respond_to?(:call)
        @value_proc.call(object, self)
      else
        super(object)
      end
    end
  end

  module TimeEntryQueryPatch
    def self.included(base)
      base.class_eval do
        alias_method :available_columns_without_issue, :available_columns

        # Сохраняем оригинальные реализации суммирования, если они определены.
        alias_method :total_for_hours_without_custom, :total_for_hours if method_defined?(:total_for_hours)
        alias_method :total_by_group_for_without_custom, :total_by_group_for if method_defined?(:total_by_group_for)

        def available_columns
          @available_columns ||= begin
                                   cols = available_columns_without_issue

                                   # Обработка колонки :issue (группировка по задаче)
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

                                   # Добавляем колонку :parent_issue для группировки по родительским задачам,
                                   # если её ещё нет в списке. Используем QueryColumnWithProc с лямбдой,
                                   # которая возвращает: если у записи есть связанная задача, то её родитель (если есть),
                                   # иначе – саму задачу.
                                   unless cols.any? { |c| c.name == :parent_issue }
                                     Rails.logger.info "DEBUG: [available_columns] Добавляем колонку :parent_issue для группировки по родительским задачам"
                                     cols << QueryColumnWithProc.new(:parent_issue,
                                                                     :caption   => :field_parent_issue,
                                                                     :groupable => "COALESCE(#{Issue.table_name}.parent_id, #{Issue.table_name}.id)",
                                                                     :sortable  => "COALESCE(#{Issue.table_name}.parent_id, #{Issue.table_name}.id)",
                                                                     :value     => lambda { |entry, _column|
                                                                       if entry.issue
                                                                         entry.issue.parent || entry.issue
                                                                       else
                                                                         nil
                                                                       end
                                                                     }
                                     )
                                   end

                                   # Обработка колонки :hours (суммирование)
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

                                   # Добавляем дополнительные колонки для отображения оценки из задачи:
                                   # - time_estimate – значение берётся из issues.estimated_hours;
                                   # - total_time_estimate – вычисляется как сумма оценки родительской задачи и оценок её подзадач.
                                   extra_issue_fields = {
                                     time_estimate: {
                                       caption:    :field_time_estimate,        # "Оценка временных затрат"
                                       sortable:   "issues.estimated_hours",
                                       groupable:  false,
                                       value:      lambda { |entry, _column|
                                         v = entry.issue.try(:estimated_hours)
                                         v = 0.0 if v.nil?
                                         v.to_f
                                       }
                                     },
                                     total_time_estimate: {
                                       caption:    :field_total_time_estimate,    # "Общая оценка временных затрат"
                                       sortable:   false,
                                       groupable:  false,
                                       value:      lambda { |entry, _column|
                                         if issue = entry.issue
                                           parent_estimate = issue.estimated_hours.to_f
                                           children_sum = issue.children.sum(:estimated_hours).to_f
                                           Rails.logger.debug "DEBUG: Issue #{issue.id}: parent_estimate=#{parent_estimate}, children_sum=#{children_sum}"
                                           parent_estimate + children_sum
                                         else
                                           0.0
                                         end
                                       }
                                     }
                                   }

                                   extra_issue_fields.each do |field, options|
                                     unless cols.any? { |c| c.name == field }
                                       Rails.logger.info "DEBUG: [available_columns] Добавляем колонку :#{field} с опциями #{options.inspect}"
                                       cols << QueryColumnWithProc.new(field, options)
                                     end
                                   end

                                   Rails.logger.info "DEBUG: [available_columns] Итоговый список колонок: #{cols.map(&:name).inspect}"
                                   cols
                                 end
        end

        # Метод group_by_statement:
        # Если группировка по :issue – возвращаем выражение для группировки по issue_id;
        # если по :parent_issue – возвращаем выражение COALESCE(issues.parent_id, issues.id);
        # иначе – стандартное поведение.
        def group_by_statement
          return nil unless grouped?
          if group_by_column.name == :issue
            Rails.logger.info "DEBUG: [group_by_statement] Группировка по :issue, возвращаем '#{TimeEntry.table_name}.issue_id'"
            return "#{TimeEntry.table_name}.issue_id"
          elsif group_by_column.name == :parent_issue
            Rails.logger.info "DEBUG: [group_by_statement] Группировка по :parent_issue, возвращаем COALESCE(#{Issue.table_name}.parent_id, #{Issue.table_name}.id)"
            return "COALESCE(#{Issue.table_name}.parent_id, #{Issue.table_name}.id)"
          end
          super
        end

        # Метод total_for_hours:
        # Если группировка по :issue или :parent_issue – вычисляем сумму через scope.sum,
        # иначе – вызываем оригинальную реализацию.
        def total_for_hours(scope)
          if grouped? && (group_by_column.name == :issue || group_by_column.name == :parent_issue)
            result = scope.sum("#{TimeEntry.table_name}.hours")
            result = result.is_a?(Hash) ? result.values.sum : result
            Rails.logger.info "DEBUG: [total_for_hours] Сумма часов (группировка по #{group_by_column.name}): #{result} для SQL: #{scope.to_sql}"
            result.to_f
          else
            total_for_hours_without_custom(scope)
          end
        end

        # Метод total_by_group_for:
        # Если группировка по :issue – группируем по issue_id и преобразуем ключи в объекты Issue;
        # если по :parent_issue – группируем по COALESCE(issues.parent_id, issues.id) и преобразуем ключи в объекты родительских задач;
        # иначе – вызываем оригинальную реализацию.
        def total_by_group_for(column)
          if grouped? && column.name == :hours
            if group_by_column.name == :issue
              result = {}
              grouped_query do |scope|
                Rails.logger.info "DEBUG: [total_by_group_for] В блоке grouped_query (группировка по :issue). SQL: #{scope.unscope(:order).to_sql}"
                result = scope.unscope(:order).group("#{TimeEntry.table_name}.issue_id").sum("#{TimeEntry.table_name}.hours")
                Rails.logger.info "DEBUG: [total_by_group_for] Результат группировки (issue): #{result.inspect}"
              end
              issue_ids = result.keys.map { |key| key.is_a?(Array) ? key.first : key }
              issues = Issue.where(id: issue_ids).index_by(&:id)
              transformed_result = result.each_with_object({}) do |(group_key, hours), hash|
                issue_id = group_key.is_a?(Array) ? group_key.first : group_key
                if issues[issue_id]
                  hash[issues[issue_id]] = hours.to_f
                else
                  Rails.logger.warn "WARN: Issue с id=#{issue_id} не найден"
                end
              end
              Rails.logger.info "DEBUG: [total_by_group_for] Итоговый результат (issue): #{transformed_result.inspect}"
              return transformed_result
            elsif group_by_column.name == :parent_issue
              group_expr = "COALESCE(#{Issue.table_name}.parent_id, #{Issue.table_name}.id)"
              result = {}
              grouped_query do |scope|
                Rails.logger.info "DEBUG: [total_by_group_for] В блоке grouped_query (группировка по :parent_issue). SQL: #{scope.unscope(:order).to_sql}"
                result = scope.unscope(:order).group(group_expr).sum("#{TimeEntry.table_name}.hours")
                Rails.logger.info "DEBUG: [total_by_group_for] Результат группировки (parent_issue): #{result.inspect}"
              end
              # Если ключ – массив, берем первый элемент
              parent_ids = result.keys.map { |k| k.is_a?(Array) ? k.first : k }
              parent_issues = Issue.where(id: parent_ids).index_by(&:id)
              transformed_result = result.each_with_object({}) do |(group_key, hours), hash|
                issue_id = group_key.is_a?(Array) ? group_key.first : group_key
                if parent_issues[issue_id]
                  hash[parent_issues[issue_id]] = hours.to_f
                else
                  Rails.logger.warn "WARN: Родительская задача с id=#{issue_id} не найдена"
                end
              end
              Rails.logger.info "DEBUG: [total_by_group_for] Итоговый результат (parent_issue): #{transformed_result.inspect}"
              return transformed_result
            end
          end
          total_by_group_for_without_custom(column)
        end

        # Формирование JOIN-ов для сортировки.
        # Если группировка по :issue или :parent_issue – добавляем LEFT OUTER JOIN с таблицей issues.
        def joins_for_order_statement(order_options = nil)
          joins = []
          if grouped? && (group_by_column.name == :issue || group_by_column.name == :parent_issue)
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