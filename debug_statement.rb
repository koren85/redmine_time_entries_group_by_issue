#!/usr/bin/env ruby

# Отладка метода statement
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/debug_statement.rb

puts "=" * 80
puts "Отладка метода statement"
puts "=" * 80

query = TimeEntryQuery.new
query.add_filter('parent_issue_id', '=', ['100'])

puts "\n1. Состояние запроса:"
puts "   Фильтры: #{query.filters.inspect}"
puts "   Валидность: #{query.valid?}"
if !query.valid?
  puts "   Ошибки валидации: #{query.errors.full_messages}"
end

puts "\n2. Отладка statement:"

# Переопределим метод statement для отладки
class TimeEntryQuery
  def debug_statement
    puts "   [DEBUG] Начало метода statement"
    filters_clauses = []

    if filters.nil?
      puts "   [DEBUG] filters = nil"
    else
      puts "   [DEBUG] filters = #{filters.inspect}"
    end

    if valid?
      puts "   [DEBUG] Запрос валидный"
    else
      puts "   [DEBUG] Запрос НЕ валидный!"
      return nil
    end

    filters.each_key do |field|
      puts "\n   [DEBUG] Обработка поля: #{field}"

      if field == "subproject_id"
        puts "   [DEBUG] Пропускаем subproject_id"
        next
      end

      v = values_for(field).clone
      puts "   [DEBUG] Значения: #{v.inspect}"

      if v.nil? || v.empty?
        puts "   [DEBUG] Значения пустые, пропускаем"
        next
      end

      operator = operator_for(field)
      puts "   [DEBUG] Оператор: #{operator}"

      # Проверяем различные типы полей
      if field =~ /^cf_(\d+)\.cf_(\d+)$/
        puts "   [DEBUG] Это цепочечное пользовательское поле"
      elsif field =~ /cf_(\d+)$/
        puts "   [DEBUG] Это пользовательское поле"
      elsif field =~ /^cf_(\d+)\.(.+)$/
        puts "   [DEBUG] Это атрибут пользовательского поля"
      else
        method = "sql_for_#{field.tr('.','_')}_field"
        puts "   [DEBUG] Проверяем метод: #{method}"

        if respond_to?(method)
          puts "   [DEBUG] Метод найден, вызываем..."
          begin
            sql = send(method, field, operator, v)
            puts "   [DEBUG] SQL: #{sql}"
            filters_clauses << sql if sql.present?
          rescue => e
            puts "   [DEBUG] ОШИБКА при вызове: #{e.message}"
            puts e.backtrace[0..3].join("\n")
          end
        else
          puts "   [DEBUG] Метод не найден, используем стандартный sql_for_field"
          sql = '(' + sql_for_field(field, operator, v, queried_table_name, field) + ')'
          puts "   [DEBUG] SQL: #{sql}"
          filters_clauses << sql
        end
      end
    end

    # Добавляем project_statement
    project_sql = project_statement
    puts "\n   [DEBUG] project_statement: #{project_sql.inspect}"
    filters_clauses << project_sql if project_sql.present?

    puts "\n   [DEBUG] Всего фильтров: #{filters_clauses.count}"
    puts "   [DEBUG] Фильтры: #{filters_clauses.inspect}"

    result = filters_clauses.any? ? filters_clauses.join(' AND ') : nil
    puts "   [DEBUG] Результат: #{result.inspect}"

    result
  end
end

puts "\n3. Вызов debug_statement:"
statement = query.debug_statement

puts "\n4. Итоговый statement:"
if statement.blank?
  puts "   ✗ Statement пустой!"
else
  puts "   ✓ Statement: #{statement}"
end

# Проверим стандартный statement
puts "\n5. Стандартный statement:"
begin
  std_statement = query.statement
  if std_statement.blank?
    puts "   ✗ Стандартный statement тоже пустой!"
  else
    puts "   ✓ Стандартный statement: #{std_statement}"
  end
rescue => e
  puts "   ✗ Ошибка: #{e.message}"
end

puts "\n" + "=" * 80
puts "Отладка завершена"
puts "=" * 80