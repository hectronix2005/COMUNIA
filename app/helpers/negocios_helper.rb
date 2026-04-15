module NegociosHelper
  def contacto_href(contacto)
    return "#" if contacto.blank?
    c = contacto.strip
    if c =~ /\A[^@\s]+@[^@\s]+\z/
      "mailto:#{c}"
    elsif c =~ /\A\+?[\d\s\-().]{6,}\z/
      "tel:#{c.gsub(/[^\d+]/, '')}"
    elsif c =~ /\Ahttps?:\/\//i
      c
    else
      "mailto:?body=#{ERB::Util.url_encode(c)}"
    end
  end
end
