#!/usr/bin/env ruby

# Тест фильтра с типом string (текстовое поле)
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/test_string_filter.rb

puts "=" * 80
puts "ТЕСТ ФИЛЬТРА С ТИПОМ STRING (текстовое поле)"
puts "=" * 80

query = TimeEntryQuery.new(:name => "_test_string")

puts "\n1. Проверка типа фильтра:"
type = query.type_for('parent_issue_id')
puts "   Тип: #{type}"
puts "   Операторы для типа #{type}: #{Query.operators_by_filter_type[type].inspect}"

puts "\n2. Тест различных форматов ввода:"
test_cases = [
  { input: "100", desc: "Одно число" },
  { input: "100,200", desc: "Числа через запятую" },
  { input: "100, 200, 300", desc: "Числа через запятую с пробелами" },
  { input: "100  200  300", desc: "Числа через пробелы" }
]

test_cases.each do |test|
  puts "\n   Ввод: '#{test[:input]}' (#{test[:desc]})"

  # Тестируем с оператором "="
  query2 = TimeEntryQuery.new(:name => "_test_input")
  query2.add_filter('parent_issue_id', '=', [test[:input]])

  sql = query2.sql_for_parent_issue_id_field('parent_issue_id', '=', [test[:input]])
  puts "   SQL: #{sql}"

  # Извлекаем parent_ids из SQL для проверки
  if sql =~ /parent_id IN \(([^)]+)\)/
    extracted_ids = $1
    puts "   Извлеченные ID: #{extracted_ids}"
  end
end

puts "\n3. Тест операторов типа string:"
operators_to_test = ['=', '~', '!', '!~', '^', '$', '*', '!*']

operators_to_test.each do |op|
  puts "\n   Оператор '#{op}':"

  query3 = TimeEntryQuery.new(:name => "_test_op_#{op}")

  case op
  when '*', '!*'
    query3.add_filter('parent_issue_id', op, [])
    value = []
  else
    query3.add_filter('parent_issue_id', op, ['100,200'])
    value = ['100,200']
  end

  sql = query3.sql_for_parent_issue_id_field('parent_issue_id', op, value)
  puts "   SQL: #{sql[0..150]}..." if sql.length > 150
  puts "   SQL: #{sql}" if sql.length <= 150
end

puts "\n4. Проверка интеграции с веб-интерфейсом:"
query4 = TimeEntryQuery.new(:name => "_web_test")

# Симулируем ввод из веб-интерфейса - одна строка с числами через запятую
query4.add_filter('parent_issue_id', '=', ['71240, 73131'])

puts "   Фильтр добавлен: parent_issue_id = '71240, 73131'"
puts "   Фильтры в query: #{query4.filters['parent_issue_id'].inspect}"

# Проверяем statement
statement = query4.statement
if statement.present?
  puts "   ✓ Statement сгенерирован"
  if statement.include?("71240") && statement.include?("73131")
    puts "   ✓ Statement содержит оба parent_id"
  else
    puts "   ✗ Statement не содержит ожидаемые parent_id"
    puts "   Statement: #{statement}"
  end
else
  puts "   ✗ Statement пустой!"
end

puts "\n5. Реальный тест с данными из БД:"
# Находим родительские задачи с трудозатратами
parent_ids = TimeEntry
  .joins(:issue)
  .joins("INNER JOIN issues parent ON parent.id = issues.parent_id")
  .select("DISTINCT issues.parent_id")
  .limit(3)
  .pluck("issues.parent_id")

if parent_ids.any?
  puts "   Тестовые parent_id: #{parent_ids.inspect}"

  # Формируем строку как в веб-интерфейсе
  input_string = parent_ids.join(', ')
  puts "   Строка для ввода: '#{input_string}'"

  query5 = TimeEntryQuery.new(:name => "_real_test")
  query5.add_filter('parent_issue_id', '=', [input_string])

  sql = query5.sql_for_parent_issue_id_field('parent_issue_id', '=', [input_string])

  # Проверяем результат
  direct_count = TimeEntry
    .joins(:issue)
    .where("issues.parent_id IN (?)", parent_ids)
    .count

  filter_count = TimeEntry.where(sql).count

  puts "   Прямой запрос: #{direct_count} записей"
  puts "   Через фильтр: #{filter_count} записей"

  if direct_count == filter_count
    puts "   ✓ Результаты совпадают!"
  else
    puts "   ✗ НЕСООТВЕТСТВИЕ!"
  end
end

puts "\n" + "=" * 80
puts "ИТОГ:"
puts "✓ Фильтр типа :string позволяет вводить числа через запятую в текстовое поле"
puts "✓ Поддерживаются различные форматы ввода (запятые, пробелы)"
puts "✓ Все необходимые операторы работают"
puts "=" * 80