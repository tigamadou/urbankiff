import { Suspense } from 'react'
import ReactDOM from 'react-dom'
import { act } from 'react-dom/test-utils'
import { Provider } from 'react-redux'
import { store } from './redux/store'
import { ThemeContext } from './utility/context/ThemeColors'
import App from './App'

it('renders without crashing', async () => {
  const div = document.createElement('div')
  await act(async () => {
    ReactDOM.render(
      <Provider store={store}>
        <Suspense fallback={null}>
          <ThemeContext>
            <App />
          </ThemeContext>
        </Suspense>
      </Provider>,
      div
    )
  })
  expect(div.innerHTML).not.toBe('')
  ReactDOM.unmountComponentAtNode(div)
})
