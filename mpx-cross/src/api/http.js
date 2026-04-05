import { getToken } from '../utils/storage'

const BASE_URL = 'http://127.0.0.1:3000/api'

export function request({ url, method = 'GET', data = {} }) {
  return new Promise((resolve, reject) => {
    mpx.request({
      url: `${BASE_URL}${url}`,
      method,
      data,
      header: {
        Authorization: getToken() ? `Bearer ${getToken()}` : ''
      },
      success(res) {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(res.data)
        } else {
          reject(res.data || { message: '请求失败' })
        }
      },
      fail: reject
    })
  })
}
