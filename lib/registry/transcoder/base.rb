module Registry
  module Transcoder

    # Convert native type to String which will be stored in the database.
    def self.to_db(value)
      case value
        when Array                  then "[#{value.map {|ii| to_db(ii)}.join(',')}]"
        when Date                   then value.strftime("%Y-%m-%d")
        when Symbol                 then ":#{value}"
        when Time                   then value.strftime("%Y-%m-%d %H:%M:%S %Z")
        when TrueClass,FalseClass   then value ? 'true' : 'false'
        else                             value.to_s
      end
    end

    # Convert String from the database to native type which will be used by the caller.
    def self.from_db(value)
      return value unless value.is_a?(String)

      return value[1 .. -2].split(',').map {|ii| from_db(ii)}   if value[0,1] == '[' and value[-1,1] == ']' # array
      return 'true' == value                                    if value =~ /\A(true|false)\z/i             # boolean
      return eval(value)                                        if value =~ /\A:/                           # symbol
      return from_db_range(value)                               if value =~ /\.\./                          # range
      return Date.parse(value)                                  if value =~ /\A\d+-\d+-\d+\z/               # date
      return Time.parse(value)                                  if value =~ /\A\d+-\d+-\d+ \d+:\d+:\d+/     # time
      return value                                              if value =~ /\A\d+(\.\d+){2,3}\z/           # ip address
      return value.to_i                                         if value =~ /\A[-+]?[\d_,]+\z/              # int
      return value.to_f                                         if value =~ /\A[-+]?[\d_,.]+\z/             # float

      value                                                                                                 # string
    end

    # Try to convert a String from the database to a ruby range.
    def self.from_db_range(value)
      eval(value) rescue value
    rescue SyntaxError => ex
      return value unless ex.message =~ /octal/  # conversion failed, just return value
      from, range, to = value.match(/(.*)\s*(\.\.\.?)\s*(.*)/).to_a[1 .. -1]
      eval("#{from.to_i} #{range} #{to.to_i}")
    end

    class Base
    end # class Base
  end # module Transcoder
end # module Registry
