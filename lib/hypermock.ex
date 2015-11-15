defmodule HyperMock do
  defmacro __using__(opts) do
    adapter = opts[:adapter] || HyperMock.Adapter.IBrowse

    quote do
      :application.start(unquote(adapter).target_module)
      @adapter unquote(adapter)
    end
  end

  def stub_request(request, response \\ %HyperMock.Response{}) do
    HyperMock.Registry.put request, response
  end

  def verify_expectations do
    unused_stubs = HyperMock.Registry.all
      |> Enum.filter_map(fn({_,_,count}) -> count == 0 end, fn({req,_,_}) -> req end)

    if Enum.any?(unused_stubs), do: raise(HyperMock.UnmetExpectationError, unused_stubs)
  end

  defmacro intercept(test) do
    quote do
      import unquote(__MODULE__)

      alias HyperMock.Request
      alias HyperMock.Response
      alias HyperMock.Registry

      populate_adapter @adapter

      Registry.start_link

      run_mock(unquote(test), @adapter)

    end
  end

  defmacro intercept_with(request, response \\ %HyperMock.Response{}, test) do
    quote do
      import unquote(__MODULE__)

      alias HyperMock.Registry

      populate_adapter @adapter

      Registry.start_link

      stub_request unquote(request), unquote(response)

      run_mock(unquote(test), @adapter)

    end
  end

  def populate_adapter(adapter) do
    for {fun, imp} <- adapter.request_functions do
      :meck.expect(adapter.target_module, fun, imp)
    end
  end

  def run_mock(test, adapter) do
    try do
      test
      verify_expectations
    after
      :meck.unload adapter.target_module
      HyperMock.Registry.stop
    end
  end

end
