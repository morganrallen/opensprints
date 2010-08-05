#Arduino: a sensor written for the arduino open source hardware.
class Sensor
  attr_accessor :queue
  attr_accessor :version
  def initialize(filename=nil)
    raise MissingArduinoError unless File.writable?(filename)
    #HACK oogity boogity magic happens here:
	if RUBY_PLATFORM.index("darwin") > -1
		@f = File.open(filename, 'w+')
		`stty -f #{filename} cs8 115200 ignbrk -brkint -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke -noflsh -ixon -crtscts`
	else
		`stty -F #{filename} cs8 115200 ignbrk -brkint -icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke -noflsh -ixon -crtscts`
		@f = File.open(filename, 'w+')
	end

    ticks = ($RACE_DISTANCE / $ROLLER_CIRCUMFERENCE).floor
    # need to gracefully continue if no response (i.e. versions before basic-1)
    #get_version

    send_length(ticks)
  end

  def get_version
    begin
      Timeout.timeout(2){
        sleep(1)
        @f.flush
        @f.putc ?v
        @f.flush
        puts "getting version"
        @version = @f.readline
        puts "version: #{@version}"
      }
    rescue Timeout::Error
      puts "Timeout getting version"
    end
  end

  def send_length(ticks)
    begin
      Timeout.timeout(1.0){
        @f.flush
        @f.putc ?l
        @f.putc(ticks % 256)
        @f.putc(ticks / 256)
        @f.putc ?\r
        puts "setting length"
        @length_status = @f.readline
        puts "length status: #{@length_status}"
      }
    rescue Timeout::Error
      puts "Timeout setting length"
    else
      #TODO raise an ErrorReceivingTickLength and catch it in the app like
      #   we do with a missing arduino error.
      #raise @length_status unless @length_status=~/OK/
    end
  end

  def start
    @t.kill if @t
    @t = Thread.new do
      @f.putc 'g'
      Thread.current["racers"] = [[],[],[],[]]
      Thread.current["finish_times"] = []
      @f.flush
      while true do
        l = @f.readline
        if l=~/:/
          if l =~ /0:/
            Thread.current["racers"][0] =  [0] * l.gsub(/0: /,'').to_i
          end
          if l =~ /1:/
            Thread.current["racers"][1] =  [1] * l.gsub(/1: /,'').to_i
          end
          if l =~ /2:/
            Thread.current["racers"][2] =  [2] * l.gsub(/2: /,'').to_i
          end
          if l =~ /3:/
            Thread.current["racers"][3] =  [3] * l.gsub(/3: /,'').to_i
          end
          if l =~ /0f:/
            Thread.current["finish_times"][0] = l.gsub(/0f: /,'').to_i
          end
          if l =~ /1f:/
            Thread.current["finish_times"][1] = l.gsub(/1f: /,'').to_i
          end
          if l =~ /2f:/
            Thread.current["finish_times"][2] = l.gsub(/2f: /,'').to_i
          end
          if l =~ /3f:/
            Thread.current["finish_times"][3] = l.gsub(/3f: /,'').to_i
          end
          if l =~ /t:/
            Thread.current["time"] = l.gsub(/t: /,'').to_i
          end
        end
        puts l
      end
    end
    self
  end

  def finish_times
    @t['finish_times'] || []
  end

  def racers
    @t['racers'] || [[],[],[],[]]
  end

  def time
    @t['time'] || 0
  end

  def stop
    @f.puts 's'
    @f.flush
    @t.kill
  end
end
