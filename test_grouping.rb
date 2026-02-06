#!/usr/bin/env ruby

# Тестирование существующего функционала группировки
# Запускать из корневой директории Redmine:
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/test_grouping.rb

puts "=" * 80
puts "Тестирование существующего функционала группировки"
puts "=" * 80

# Проверяем доступные колонки
query = TimeEntryQuery.new
columns = query.available_columns

puts "\nДоступные колонки для группировки:"
groupable_columns = columns.select { |c| c.groupable }
groupable_columns.each do |col|
  puts "  - #{col.name}: groupable = #{col.groupable}"
end

# Проверяем колонки, добавленные плагином
plugin_columns = [:issue, :parent_issue, :time_estimate, :total_time_estimate]
puts "\nКолонки плагина:"
plugin_columns.each do |col_name|
  col = columns.find { |c| c.name == col_name }
  if col
    puts "  ✓ #{col_name} найдена"
    puts "    - groupable: #{col.groupable}" if col.groupable
    puts "    - totalable: #{col.totalable}" if col.respond_to?(:totalable) && col.totalable
  else
    puts "  ✗ #{col_name} НЕ найдена!"
  end
end

# Тест группировки по issue
puts "\n" + "=" * 80
puts "Тест группировки по задаче (issue):"
puts "=" * 80

query2 = TimeEntryQuery.new
query2.group_by = 'issue'
puts "Установлена группировка: #{query2.group_by}"
puts "group_by_statement: #{query2.group_by_statement}"

# Тест группировки по parent_issue
puts "\n" + "=" * 80
puts "Тест группировки по родительской задаче (parent_issue):"
puts "=" * 80

query3 = TimeEntryQuery.new
query3.group_by = 'parent_issue'
puts "Установлена группировка: #{query3.group_by}"
puts "group_by_statement: #{query3.group_by_statement}"

# Проверяем метод joins_for_order_statement
puts "\n" + "=" * 80
puts "Проверка JOIN-ов для сортировки:"
puts "=" * 80

[nil, 'issue', 'parent_issue'].each do |group_by|
  query4 = TimeEntryQuery.new
  query4.group_by = group_by
  joins = query4.joins_for_order_statement
  puts "group_by = #{group_by.inspect}:"
  puts "  joins = #{joins.inspect}"
end

puts "\n" + "=" * 80
puts "Все тесты группировки завершены успешно!"
puts "=" * 80