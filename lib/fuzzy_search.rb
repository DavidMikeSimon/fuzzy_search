require 'ar-extensions' # External dependency
# Monkey patch a bug in ar-extensions which breaks postgres compatibility
module ActiveRecord # :nodoc:
  module ConnectionAdapters # :nodoc:
    class AbstractAdapter # :nodoc:
      def next_value_for_sequence(sequence_name)
        %{nextval('#{sequence_name}')}
      end
    end
  end
end

require 'fuzzy_search_trigram'
require 'fuzzy_search_ver'
require 'model_extensions'

ActiveRecord::Base.send(:include, FuzzySearch::ModelExtensions)
