module Merb::Test::Fixtures::Controllers
  class Testing < Merb::Controller
    self._template_root = File.dirname(__FILE__) / "views"
  end

  class SimpleRedirect < Testing
    def index
      redirect("/")
    end
  end

  class RedirectViaHalt < Testing
    def index
      throw :halt, redirect("/")
    end
  end

  class PermanentRedirect < Testing
    def index
      redirect("/", :permanent => true)
    end
  end
  
  class PermanentAndStatusRedirect < Testing
    def index
      redirect("/", :permanent => true, :status => 302)
    end
  end

  class WithStatusRedirect < Testing
    def index
      redirect("/", :status => 307)
    end
  end

  class RedirectWithMessage < Testing
    def index
      redirect("/", :message => { :notice => "what?" })
    end
  end
  
  class RedirectWithNotice < Testing
    def index
      redirect("/", :notice => "what?")
    end
  end

  class RedirectWithError < Testing
    def index
      redirect("/", :error => "errored!")
    end
  end
  
  class RedirectWithMessageAndFragment < Testing
    def index
      redirect("/#someanchor", :message => { :notice => "what?" }, :fragment => "someanchor")
    end
  end

  class ConsumesMessage < Testing
    def index
      message[:notice]
    end
  end
  
  class SetsMessage < Testing
    def index
      message[:notice] = "Hello"
      message[:notice]
    end
  end
end
