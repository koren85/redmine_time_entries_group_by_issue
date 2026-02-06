#!/usr/bin/env ruby

# Простой скрипт для проверки нового фильтра родительских задач
# Запускать из корневой директории Redmine:
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/test_filter.rb

puts "=" * 80
puts "Тестирование фильтра родительских задач"
puts "=" * 80

# Создаем новый TimeEntryQuery
query = TimeEntryQuery.new

# Проверяем, что наш фильтр добавлен
puts "\nДоступные фильтры:"
available_filters = query.available_filters
if available_filters['parent_issue_id']
  puts "✓ Фильтр 'parent_issue_id' найден!"
  puts "  - Тип: #{query.type_for('parent_issue_id')}"
  # Получаем операторы для типа integer
  operators = Query.operators_by_filter_type[:integer]
  puts "  - Доступные операторы: #{operators.inspect}"
else
  puts "✗ Фильтр 'parent_issue_id' НЕ найден!"
end

# Проверяем SQL генерацию для разных операторов
puts "\n" + "=" * 80
puts "Проверка SQL для разных операторов:"
puts "=" * 80

test_cases = [
  { operator: "=", values: ["100", "200"], desc: "Содержит родителей 100, 200" },
  { operator: "!", values: ["100"], desc: "Не содержит родителя 100" },
  { operator: "*", values: [], desc: "Есть родитель" },
  { operator: "!*", values: [], desc: "Нет родителя" }
]

test_cases.each do |test|
  puts "\n#{test[:desc]} (оператор: #{test[:operator]}):"
  begin
    sql = query.sql_for_parent_issue_id_field('parent_issue_id', test[:operator], test[:values])
    puts "  SQL: #{sql}"
  rescue => e
    puts "  Ошибка: #{e.message}"
  end
end

# Тест с реальным фильтром
puts "\n" + "=" * 80
puts "Тест применения фильтра к запросу:"
puts "=" * 80

query2 = TimeEntryQuery.new
query2.add_filter('parent_issue_id', '=', ['1'])
puts "Добавлен фильтр: parent_issue_id = 1"
puts "Активные фильтры: #{query2.filters.inspect}"

# Проверяем statement
begin
  statement = query2.statement
  puts "\nИтоговый SQL WHERE clause:"
  puts statement
rescue => e
  puts "Ошибка при генерации statement: #{e.message}"
  puts e.backtrace[0..5].join("\n")
end

puts "\n" + "=" * 80
puts "Тестирование завершено!"
puts "=" * 80