module Registry
  module Transcoder

    # Convert native type to String which will be stored in the database.
    def self.to_db(value)
      transcoders.each do |transcoder|
        return transcoder.to_db(value) if transcoder.matches?(value)
      end

      return value.to_s
    end

    # Convert String from the database to native type which will be used by the caller.
    def self.from_db(string)
      transcoders.each do |transcoder|
        return transcoder.from_db(string) if transcoder.matches?(string)
      end

      return string
    end

    # Try to convert a String from the database to a ruby range.
    def self.from_db_range(value)
      eval(value)
    rescue SyntaxError => ex
      return value unless ex.message =~ /octal/  # conversion failed, just return value
      from, range, to = value.match(/(.*)\s*(\.\.\.?)\s*(.*)/).to_a[1 .. -1]
      eval("#{from.to_i} #{range} #{to.to_i}")
    end

    def self.transcoders
      @transcoders ||= []
    end

    class Base

      # return true if this instance should be used to transcode value to or from the database
      def matches?(value)
        return false
      end

      # Convert value to String which will be stored in the database.
      def to_db(value)
        return value.to_s
      end

      # Convert String from the database to native type which will be used by the caller.
      def from_db(string)
        return string
      end

    end # class Base
  end # module Transcoder
end # module Registry
