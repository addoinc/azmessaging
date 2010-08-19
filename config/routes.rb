Rails.application.routes.draw do |map|
  map.resources(
    :messages, :member => {
      :markread => :put, :markunread => :put
    }, :collection => { :reply => :post }
  )
end
