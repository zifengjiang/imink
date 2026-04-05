import { request } from './http'

export const fetchSchedules = () => request({ url: '/schedules' })
export const fetchBattles = () => request({ url: '/battles' })
export const fetchCoops = () => request({ url: '/coops' })
