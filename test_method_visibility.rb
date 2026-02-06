#!/usr/bin/env ruby

# Проверка видимости метода sql_for_parent_issue_id_field
# bundle exec rails runner plugins/redmine_time_entries_group_by_issue/test_method_visibility.rb

puts "=" * 80
puts "Проверка видимости методов"
puts "=" * 80

query = TimeEntryQuery.new

puts "\n1. Проверка наличия метода sql_for_parent_issue_id_field:"
if query.respond_to?(:sql_for_parent_issue_id_field)
  puts "   ✓ Метод ВИДЕН через respond_to?"
else
  puts "   ✗ Метод НЕ ВИДЕН через respond_to?"
end

puts "\n2. Проверка через method_defined?:"
if TimeEntryQuery.method_defined?(:sql_for_parent_issue_id_field)
  puts "   ✓ Метод определен в классе"
else
  puts "   ✗ Метод НЕ определен в классе"
end

puts "\n3. Проверка через instance_methods:"
if TimeEntryQuery.instance_methods.include?(:sql_for_parent_issue_id_field)
  puts "   ✓ Метод есть в instance_methods"
else
  puts "   ✗ Метода нет в instance_methods"
end

puts "\n4. Попытка прямого вызова:"
begin
  result = query.sql_for_parent_issue_id_field('parent_issue_id', '=', ['100'])
  puts "   ✓ Метод вызывается напрямую"
  puts "   Результат: #{result}"
rescue => e
  puts "   ✗ Ошибка при вызове: #{e.message}"
end

puts "\n5. Проверка через send:"
begin
  result = query.send(:sql_for_parent_issue_id_field, 'parent_issue_id', '=', ['100'])
  puts "   ✓ Метод вызывается через send"
  puts "   Результат: #{result}"
rescue => e
  puts "   ✗ Ошибка при вызове через send: #{e.message}"
end

puts "\n6. Проверка имени метода для respond_to?:"
field = "parent_issue_id"
method_name = "sql_for_#{field.tr('.','_')}_field"
puts "   Имя метода: #{method_name}"
if query.respond_to?(method_name)
  puts "   ✓ respond_to?('#{method_name}') = true"
else
  puts "   ✗ respond_to?('#{method_name}') = false"
end

puts "\n7. Список всех методов sql_for_*:"
sql_methods = TimeEntryQuery.instance_methods.select { |m| m.to_s.start_with?('sql_for_') }
puts "   Найдено методов sql_for_*: #{sql_methods.count}"
sql_methods.each do |method|
  puts "   - #{method}"
end

puts "\n" + "=" * 80
puts "Тестирование завершено"
puts "=" * 80