#!/usr/bin/env ruby

# Диагностический скрипт для проверки фильтра родительских задач
# Запускать из корневой директории Redmine:
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/diagnose_filter.rb

puts "=" * 80
puts "Диагностика фильтра родительских задач"
puts "=" * 80

# Получаем тестовые parent_id из БД
parent_ids = Issue.where.not(parent_id: nil)
                  .select(:parent_id)
                  .distinct
                  .limit(3)
                  .pluck(:parent_id)

if parent_ids.empty?
  puts "В БД нет задач с родителями для тестирования"
  exit
end

puts "\nТестовые parent_id: #{parent_ids.inspect}"

parent_ids.each do |parent_id|
  puts "\n" + "-" * 80
  puts "Анализ для parent_id = #{parent_id}"
  puts "-" * 80

  # 1. Найдем все дочерние задачи этого родителя
  child_issues = Issue.where(parent_id: parent_id)
  puts "\n1. Дочерние задачи родителя ##{parent_id}:"
  child_issues.each do |issue|
    puts "   - Задача ##{issue.id}: #{issue.subject[0..50]}"
  end
  puts "   Всего дочерних задач: #{child_issues.count}"

  # 2. Проверим трудозатраты по этим задачам напрямую
  child_issue_ids = child_issues.pluck(:id)
  direct_time_entries = TimeEntry.where(issue_id: child_issue_ids)
  puts "\n2. Трудозатраты по дочерним задачам (прямой запрос):"
  puts "   TimeEntry.where(issue_id: #{child_issue_ids.inspect})"
  puts "   Найдено записей: #{direct_time_entries.count}"

  # 3. Теперь проверим через SQL фильтра
  query = TimeEntryQuery.new
  filter_sql = query.sql_for_parent_issue_id_field('parent_issue_id', '=', [parent_id.to_s])
  puts "\n3. SQL, генерируемый фильтром:"
  puts "   #{filter_sql}"

  # Выполним этот SQL
  filtered_entries = TimeEntry.where(filter_sql)
  puts "   Найдено записей через фильтр: #{filtered_entries.count}"

  # 4. Сравним результаты
  puts "\n4. Сравнение результатов:"
  if direct_time_entries.count == filtered_entries.count
    puts "   ✓ Количество записей совпадает!"
  else
    puts "   ✗ НЕСООТВЕТСТВИЕ: прямой запрос = #{direct_time_entries.count}, фильтр = #{filtered_entries.count}"

    # Найдем разницу
    direct_ids = direct_time_entries.pluck(:id)
    filtered_ids = filtered_entries.pluck(:id)

    missing_in_filter = direct_ids - filtered_ids
    extra_in_filter = filtered_ids - direct_ids

    if missing_in_filter.any?
      puts "   Записи, пропущенные фильтром: #{missing_in_filter.inspect}"
      missing_in_filter.first(3).each do |te_id|
        te = TimeEntry.find(te_id)
        puts "     - TimeEntry ##{te_id}: issue_id=#{te.issue_id}, hours=#{te.hours}"
      end
    end

    if extra_in_filter.any?
      puts "   Лишние записи в фильтре: #{extra_in_filter.inspect}"
    end
  end

  # 5. Проверим, есть ли проблемы с NULL значениями
  puts "\n5. Проверка NULL значений:"
  null_issue_entries = TimeEntry.where(issue_id: nil).count
  puts "   Трудозатраты без задач (issue_id = NULL): #{null_issue_entries}"

  # 6. Проверим конфликт с другими фильтрами
  puts "\n6. Проверка с дополнительным фильтром spent_on:"
  query2 = TimeEntryQuery.new
  query2.add_filter('parent_issue_id', '=', [parent_id.to_s])

  # Генерируем полный statement
  full_statement = query2.statement
  puts "   Полный SQL statement: #{full_statement}"

  # Если statement пустой, это проблема
  if full_statement.blank?
    puts "   ✗ ПРОБЛЕМА: statement пустой!"
  else
    # Проверим количество с полным statement
    full_query_result = TimeEntry.where(full_statement)
    puts "   Результат с полным statement: #{full_query_result.count} записей"
  end
end

# Дополнительная проверка: конфликт типов операторов
puts "\n" + "=" * 80
puts "Проверка операторов для фильтра:"
puts "=" * 80

query = TimeEntryQuery.new
type = query.type_for('parent_issue_id')
puts "Тип фильтра: #{type}"
puts "Доступные операторы для типа #{type}: #{Query.operators_by_filter_type[type].inspect}"

# Проверим, поддерживает ли тип integer оператор "!"
if Query.operators_by_filter_type[:integer].include?("!")
  puts "✓ Оператор '!' поддерживается для типа integer"
else
  puts "✗ ПРОБЛЕМА: Оператор '!' НЕ поддерживается для типа integer!"
  puts "Это может вызывать проблемы с фильтрацией"
end

puts "\n" + "=" * 80
puts "Диагностика завершена"
puts "=" * 80