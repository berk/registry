require 'registry/transcoder/base'

Dir["#{File.dirname(__FILE__)}/transcoder/*.rb"].each do |file|
  next if file.to_s =~ /base.rb/
  require_or_load file
end

require 'ipaddr'

Registry.configure do |config|

  # Array transcoder
  config.add_transcoder do
    to_db   {|value|  "[#{value.map {|ii| Registry::Transcoder::to_db(ii)}.join(',')}]"}
    from_db {|string| string[1 .. -2].split(',').map {|ii| Registry::Transcoder::from_db(ii)}}

    matches do |value|
      value.is_a?(Array) or                                               # to_db
      (value.is_a?(String) and value[0,1] == '[' and value[-1,1] == ']')  # from_db
    end
  end

  # boolean transcoder
  config.add_transcoder do
    to_db   {|value|  value ? 'true' : 'false'}
    from_db {|string| 'true' == string}

    matches do |value|
      value.is_a?(TrueClass) or value.is_a?(FalseClass) or # to_db
      value.to_s =~ /\A(true|false)\z/i                    # from_db
    end
  end

  # Date transcoder
  config.add_transcoder do
    to_db   {|value|  value.strftime("%Y-%m-%d")}
    from_db {|string| Date.parse(string)}

    matches do |value|
      value.is_a?(Date) or              # to_db
      value.to_s =~ /\A\d+-\d+-\d+\z/   # from_db
    end
  end

  # Float transcoder
  config.add_transcoder do
    from_db {|string| string.to_f}

    matches do |value|
      value.is_a?(Float) or value.is_a?(BigDecimal) # to_db
      value.to_s =~ /\A[-+]?[\d_,]*\.\d+\z/         # from_db
    end
  end

  # Integer transcoder
  config.add_transcoder do
    from_db {|string| string.to_i}

    matches do |value|
      value.is_a?(Integer) or           # to_db
      value.to_s =~ /\A[-+]?[\d_,]+\z/  # from_db
    end
  end

  # Range transcoder
  config.add_transcoder do
    from_db do |string|
      begin
        eval(string)
      rescue SyntaxError => ex
        return string unless ex.message =~ /octal/  # conversion failed, just return value
        from, range, to = string.match(/(.*)\s*(\.\.\.?)\s*(.*)/).to_a[1 .. -1]
        eval("#{from.to_i} #{range} #{to.to_i}")
      end
    end

    matches do |value|
      value.is_a?(Range) or # to_db
      value.to_s =~ /\.\./  # from_db
    end
  end

  # Symbol transcoder
  config.add_transcoder do
    to_db   {|value|  value =~ /\A:/ ? value : ":#{value}"}
    from_db {|string| string[1 .. -1].to_sym}

    matches do |value|
      value.is_a?(Symbol) or # to_db
      value.to_s =~ /\A:/    # from_db
    end
  end

  # Time transcoder
  config.add_transcoder do
    to_db   {|value|  value.strftime("%Y-%m-%d %H:%M:%S %Z")}
    from_db {|string| Time.parse(string)}

    matches do |value|
      value.is_a?(Time) or                        # to_db
      value.to_s =~ /\A\d+-\d+-\d+ \d+:\d+:\d+/   # from_db
    end
  end
end
