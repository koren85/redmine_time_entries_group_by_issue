require 'redmine'

Redmine::Plugin.register :redmine_time_entries_group_by_issue do
  name 'Redmine Time Entries Group by Issue Plugin'
  author 'Alex Chern'
  description 'Adds the ability to group labor costs by task in reports'
  version '1.0.0'
  requires_redmine version_or_higher: '4.1.0'
end

# Подключение патчей
Rails.configuration.to_prepare do
  require_dependency 'time_entry_query_patch'
end