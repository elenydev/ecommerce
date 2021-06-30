class Configuration
  def call(event_store, command_bus)
    cqrs = Cqrs.new(event_store, command_bus)

    cqrs.subscribe(Orders::OnOrderSubmitted, [Ordering::OrderSubmitted])
    cqrs.subscribe(Orders::OnOrderExpired, [Ordering::OrderExpired])
    cqrs.subscribe(Orders::OnOrderPaid, [Ordering::OrderPaid])
    cqrs.subscribe(Orders::OnItemAddedToBasket, [Pricing::ItemAddedToBasket])
    cqrs.subscribe(Orders::OnItemRemovedFromBasket, [Pricing::ItemRemovedFromBasket])
    cqrs.subscribe(Orders::OnOrderCancelled, [Ordering::OrderCancelled])

    cqrs.subscribe(PaymentProcess.new, [
      Ordering::OrderSubmitted,
      Ordering::OrderExpired,
      Ordering::OrderPaid,
      Payments::PaymentAuthorized,
      Payments::PaymentReleased,
    ])

    cqrs.subscribe(OrderConfirmation.new, [
      Payments::PaymentAuthorized,
      Payments::PaymentCaptured
    ])

    cqrs.register(Ordering::SubmitOrder, Ordering::OnSubmitOrder.new(number_generator: Rails.configuration.number_generator.call))
    cqrs.register(Ordering::SetOrderAsExpired, Ordering::OnSetOrderAsExpired.new)
    cqrs.register(Ordering::MarkOrderAsPaid, Ordering::OnMarkOrderAsPaid.new)
    cqrs.register(Pricing::AddItemToBasket, Pricing::OnAddItemToBasket.new)
    cqrs.register(Pricing::RemoveItemFromBasket, Pricing::OnRemoveItemFromBasket.new)
    cqrs.register(Payments::AuthorizePayment, Payments::OnAuthorizePayment.new)
    cqrs.register(Payments::CapturePayment, Payments::OnCapturePayment.new)
    cqrs.register(Payments::ReleasePayment, Payments::OnReleasePayment.new)
    cqrs.register(Payments::SetPaymentAmount, Payments::OnSetPaymentAmount.new)
    cqrs.register(Ordering::CancelOrder, Ordering::OnCancelOrder.new)

    cqrs.register(Pricing::SetPrice, Pricing::SetPriceHandler.new)
    cqrs.register(Pricing::CalculateTotalValue, Pricing::OnCalculateTotalValue.new)

    cqrs.register(ProductCatalog::RegisterProduct, ProductCatalog::ProductRegistrationHandler.new)
    cqrs.subscribe(ProductCatalog::AssignPriceToProduct.new, [Pricing::PriceSet])

    cqrs.register(Crm::RegisterCustomer, Crm::CustomerRegistrationHandler.new)

    cqrs.subscribe(
      -> (event) { cqrs.run(Pricing::CalculateTotalValue.new(order_id: event.data.fetch(:order_id)))},
      [Ordering::OrderSubmitted])

    cqrs.subscribe(
      -> (event) { cqrs.run(
        Payments::SetPaymentAmount.new(
          order_id: event.data.fetch(:order_id),
          amount: event.data.fetch(:amount)
      ))},
      [Pricing::OrderTotalValueCalculated])
  end
end
