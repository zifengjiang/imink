const TOKEN_KEY = 'imink_token'

export function getToken() {
  return mpx.getStorageSync(TOKEN_KEY) || ''
}

export function setToken(token) {
  mpx.setStorageSync(TOKEN_KEY, token)
}

export function clearToken() {
  mpx.removeStorageSync(TOKEN_KEY)
}
