import { request } from './http'

export function login(payload) {
  return request({
    url: '/auth/login',
    method: 'POST',
    data: payload
  })
}

export function profile() {
  return request({
    url: '/auth/profile'
  })
}
