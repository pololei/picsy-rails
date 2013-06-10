module ApplicationHelper
  def flash_class(level)
    case level
    when :notice then "info"
    when :error then "error"
    when :alert then "warning"
    end
  end

  def current_theme?(theme)
    (cookies[:theme].blank? and theme == "default") or theme == cookies[:theme]
  end
end
