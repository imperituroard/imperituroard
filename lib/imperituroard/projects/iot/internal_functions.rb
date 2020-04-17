$LOAD_PATH.unshift File.expand_path("../projects/iot", __dir__)

require 'date'

class InternalFunc


  def printer_texter(text, log_level)
    mess = {:datetime => DateTime.now, :sdk=> "imperituroard", :sdk_version=> "0.3.3", :message => text}
    p mess
  end


  def test()
    p "eeeeeeeeeeeeeeeeeeeeeeee"
  end

end
