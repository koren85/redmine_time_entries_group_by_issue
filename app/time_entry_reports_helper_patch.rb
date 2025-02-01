module TimeEntryReportsHelperPatch
  def self.included(base)
    base.class_eval do
      alias_method :original_group_by_options, :group_by_options

      def group_by_options
        options = original_group_by_options
        unless options.any? { |opt| opt.last == 'issue_id' }
          options << [l(:field_issue), 'issue_id']
        end
        options
      end
    end
  end
end

# Включаем патч в помощник
require_dependency 'time_entry_reports_helper'
TimeEntryReportsHelper.send(:include, TimeEntryReportsHelperPatch)