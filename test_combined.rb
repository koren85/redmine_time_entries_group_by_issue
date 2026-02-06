#!/usr/bin/env ruby

# Комплексный тест фильтра родительских задач и группировки
# Запускать из корневой директории Redmine:
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/test_combined.rb

puts "=" * 80
puts "Комплексный тест: фильтр + группировка"
puts "=" * 80

# Создаем запрос с фильтром по родительской задаче И группировкой
query = TimeEntryQuery.new

# Добавляем фильтр по родительской задаче
query.add_filter('parent_issue_id', '=', ['1', '2'])
puts "\nДобавлен фильтр: parent_issue_id = [1, 2]"

# Устанавливаем группировку по задаче
query.group_by = 'issue'
puts "Установлена группировка по: issue"

puts "\nАктивные фильтры:"
query.filters.each do |field, options|
  puts "  - #{field}: #{options[:operator]} #{options[:values].inspect}"
end

puts "\ngroup_by_statement: #{query.group_by_statement}"
puts "joins_for_order_statement: #{query.joins_for_order_statement}"

# Тестируем с различными комбинациями
puts "\n" + "=" * 80
puts "Тест различных комбинаций фильтров и группировки:"
puts "=" * 80

test_cases = [
  { filter_op: '=', filter_values: ['10'], group_by: 'issue', desc: "Фильтр '=' + группировка по issue" },
  { filter_op: '!', filter_values: ['10'], group_by: 'parent_issue', desc: "Фильтр '!=' + группировка по parent_issue" },
  { filter_op: '*', filter_values: [], group_by: 'issue', desc: "Фильтр 'есть родитель' + группировка по issue" },
  { filter_op: '!*', filter_values: [], group_by: nil, desc: "Фильтр 'нет родителя' без группировки" }
]

test_cases.each_with_index do |test_case, index|
  puts "\nТест #{index + 1}: #{test_case[:desc]}"

  q = TimeEntryQuery.new
  q.add_filter('parent_issue_id', test_case[:filter_op], test_case[:filter_values])
  q.group_by = test_case[:group_by] if test_case[:group_by]

  puts "  Фильтр SQL: #{q.sql_for_parent_issue_id_field('parent_issue_id', test_case[:filter_op], test_case[:filter_values])}"
  puts "  Группировка: #{q.group_by_statement || 'нет'}"

  # Проверяем, что методы не вызывают ошибок
  begin
    q.statement
    puts "  ✓ statement() выполнен успешно"
  rescue => e
    puts "  ✗ Ошибка в statement(): #{e.message}"
  end
end

# Тест с реальными данными (если есть)
puts "\n" + "=" * 80
puts "Тест с реальными данными:"
puts "=" * 80

begin
  # Проверяем, есть ли трудозатраты в БД
  time_entries_count = TimeEntry.count
  puts "Всего трудозатрат в БД: #{time_entries_count}"

  if time_entries_count > 0
    # Находим задачи с родителями
    issues_with_parent = Issue.where.not(parent_id: nil).limit(5)
    if issues_with_parent.any?
      puts "\nНайдены задачи с родителями:"
      issues_with_parent.each do |issue|
        puts "  - Задача ##{issue.id} (родитель: ##{issue.parent_id})"

        # Проверяем трудозатраты по этой задаче
        te_count = TimeEntry.where(issue_id: issue.id).count
        puts "    Трудозатрат: #{te_count}"
      end

      # Тестируем фильтр с реальными parent_id
      parent_ids = issues_with_parent.map(&:parent_id).uniq.compact
      if parent_ids.any?
        query_real = TimeEntryQuery.new
        query_real.add_filter('parent_issue_id', '=', parent_ids.map(&:to_s))

        puts "\nТестируем фильтр с реальными parent_id: #{parent_ids.inspect}"
        sql = query_real.sql_for_parent_issue_id_field('parent_issue_id', '=', parent_ids.map(&:to_s))
        puts "SQL: #{sql}"

        # Пытаемся выполнить запрос
        begin
          scope = TimeEntry.joins(:issue)
          scope = scope.where(sql)
          count = scope.count
          puts "Найдено трудозатрат: #{count}"
        rescue => e
          puts "Ошибка при выполнении запроса: #{e.message}"
        end
      end
    else
      puts "Задач с родителями не найдено"
    end
  else
    puts "В БД нет трудозатрат для тестирования"
  end
rescue => e
  puts "Ошибка при работе с БД: #{e.message}"
end

puts "\n" + "=" * 80
puts "Комплексный тест завершен!"
puts "=" * 80