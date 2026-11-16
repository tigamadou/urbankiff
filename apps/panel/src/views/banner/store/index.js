// ** Redux Imports
import { createSlice } from '@reduxjs/toolkit'

export const appBannerSlice = createSlice({
  name: 'appBanner',
  initialState: {
    data: [],
    total: 1,
    params: {},
    allData: [],
    total: 1
  },
  reducers: {
    getBanners: (state, action) => {
      state.allData = action.payload.allData
      state.total = action.payload.total
    },
    getBannerFiltered: (state, action) => {
      state.data = action.payload.data
    },
    getBannerSearchFiltered: (state, action) => {
      state.data = action.payload.data
      state.total = action.payload.total
    }
  }
})
export const { getBanners, getBannerFiltered, getBannerSearchFiltered } = appBannerSlice.actions

export default appBannerSlice.reducer
