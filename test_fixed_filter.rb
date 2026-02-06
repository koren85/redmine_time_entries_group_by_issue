#!/usr/bin/env ruby

# Тест исправленного фильтра родительских задач
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/test_fixed_filter.rb

puts "=" * 80
puts "Тест исправленного фильтра родительских задач"
puts "=" * 80

# 1. Проверяем тип и операторы
query = TimeEntryQuery.new
puts "\n1. Проверка типа фильтра и операторов:"
type = query.type_for('parent_issue_id')
puts "   Тип фильтра: #{type}"
puts "   Доступные операторы: #{Query.operators_by_filter_type[type].inspect}"

# 2. Проверяем SQL генерацию
puts "\n2. Проверка SQL генерации:"
test_cases = [
  { op: '=', values: ['100', '200'], desc: "Содержит 100,200" },
  { op: '!', values: ['100'], desc: "Не содержит 100" },
  { op: '*', values: [], desc: "Есть родитель" },
  { op: '!*', values: [], desc: "Нет родителя" }
]

test_cases.each do |test|
  puts "\n   #{test[:desc]} (#{test[:op]}):"
  sql = query.sql_for_parent_issue_id_field('parent_issue_id', test[:op], test[:values])
  puts "   SQL: #{sql}"
end

# 3. Проверяем интеграцию с statement
puts "\n3. Проверка интеграции с общим statement:"
query2 = TimeEntryQuery.new

# Добавляем фильтр
query2.add_filter('parent_issue_id', '=', ['340', '394'])
puts "   Фильтры: #{query2.filters.inspect}"

# Генерируем statement
begin
  statement = query2.statement
  if statement.blank?
    puts "   ✗ ПРОБЛЕМА: statement пустой!"
  else
    puts "   ✓ Statement сгенерирован:"
    puts "   #{statement}"
  end
rescue => e
  puts "   ✗ Ошибка: #{e.message}"
  puts e.backtrace[0..3].join("\n")
end

# 4. Проверяем с реальными данными
puts "\n4. Проверка с реальными данными:"

# Находим родительские задачи с трудозатратами
parent_with_time_entries = TimeEntry
  .joins(:issue)
  .joins("INNER JOIN issues parent ON parent.id = issues.parent_id")
  .select("DISTINCT issues.parent_id")
  .limit(3)
  .pluck("issues.parent_id")

if parent_with_time_entries.any?
  puts "   Родительские задачи с трудозатратами: #{parent_with_time_entries.inspect}"

  parent_with_time_entries.each do |parent_id|
    puts "\n   Тест для parent_id = #{parent_id}:"

    # Прямой запрос
    direct = TimeEntry
      .joins(:issue)
      .where("issues.parent_id = ?", parent_id)
      .count
    puts "     Прямой запрос: #{direct} записей"

    # Через фильтр
    query3 = TimeEntryQuery.new
    query3.add_filter('parent_issue_id', '=', [parent_id.to_s])

    # Пробуем получить результаты
    begin
      # Используем results если метод доступен
      if query3.respond_to?(:results)
        scope = query3.results_scope
        filtered = scope.count
        puts "     Через фильтр: #{filtered} записей"

        if direct == filtered
          puts "     ✓ Совпадает!"
        else
          puts "     ✗ НЕ СОВПАДАЕТ!"
        end
      else
        puts "     (метод results недоступен)"
      end
    rescue => e
      puts "     Ошибка: #{e.message}"
    end
  end
else
  puts "   Нет родительских задач с трудозатратами"
end

# 5. Проверим множественный фильтр
puts "\n5. Проверка множественного фильтра:"
if parent_with_time_entries.size >= 2
  parent_ids = parent_with_time_entries[0..1]
  puts "   Фильтр по parent_ids: #{parent_ids.inspect}"

  # Прямой запрос
  direct = TimeEntry
    .joins(:issue)
    .where("issues.parent_id IN (?)", parent_ids)
    .count
  puts "   Прямой запрос: #{direct} записей"

  # Через фильтр
  query4 = TimeEntryQuery.new
  query4.add_filter('parent_issue_id', '=', parent_ids.map(&:to_s))

  sql = query4.sql_for_parent_issue_id_field('parent_issue_id', '=', parent_ids.map(&:to_s))
  puts "   SQL фильтра: #{sql}"

  filtered = TimeEntry.where(sql).count
  puts "   Через фильтр: #{filtered} записей"

  if direct == filtered
    puts "   ✓ Совпадает!"
  else
    puts "   ✗ НЕ СОВПАДАЕТ!"
  end
end

puts "\n" + "=" * 80
puts "Тестирование завершено"
puts "=" * 80