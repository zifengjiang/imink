import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import jwt from 'jsonwebtoken'
import bcrypt from 'bcryptjs'
import mysql from 'mysql2/promise'

dotenv.config()

const app = express()
app.use(cors())
app.use(express.json())

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST,
  port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  waitForConnections: true,
  connectionLimit: 10
})

const signToken = (user) => jwt.sign({ uid: user.id, username: user.username }, process.env.JWT_SECRET, { expiresIn: '7d' })

async function ensureDemoUser() {
  const [rows] = await pool.query('SELECT * FROM account WHERE username=?', ['demo'])
  if (rows.length > 0) return
  const hash = await bcrypt.hash('demo123456', 10)
  await pool.query(
    'INSERT INTO account(username, password_hash, nsa_id, sp3_principal_id) VALUES(?,?,?,?)',
    ['demo', hash, 'demo-nsa-id', 'demo-principal-id']
  )
}

function auth(req, res, next) {
  const authHeader = req.headers.authorization || ''
  const token = authHeader.replace('Bearer ', '')
  if (!token) return res.status(401).json({ message: '未登录' })
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET)
    next()
  } catch (e) {
    res.status(401).json({ message: '登录已过期' })
  }
}

app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body || {}
  if (!username || !password) return res.status(400).json({ message: '用户名和密码必填' })

  const [rows] = await pool.query('SELECT * FROM account WHERE username=? LIMIT 1', [username])
  const user = rows[0]
  if (!user) return res.status(401).json({ message: '账号不存在' })

  const ok = await bcrypt.compare(password, user.password_hash)
  if (!ok) return res.status(401).json({ message: '密码错误' })

  return res.json({ token: signToken(user) })
})

app.get('/api/auth/profile', auth, async (req, res) => {
  const [rows] = await pool.query('SELECT id,username,nsa_id,sp3_principal_id,created_at FROM account WHERE id=?', [req.user.uid])
  res.json({ user: rows[0] || null })
})

app.get('/api/schedules', auth, async (req, res) => {
  const [items] = await pool.query('SELECT * FROM schedule WHERE account_id=? ORDER BY start_time DESC LIMIT 20', [req.user.uid])
  res.json({ items })
})

app.get('/api/battles', auth, async (req, res) => {
  const [items] = await pool.query('SELECT id,rule,result,ko,score,played_at FROM battle WHERE account_id=? ORDER BY played_at DESC LIMIT 50', [req.user.uid])
  res.json({ items })
})

app.get('/api/coops', auth, async (req, res) => {
  const [items] = await pool.query('SELECT id,stage,danger_rate AS dangerRate,clear_waves,played_at FROM coop WHERE account_id=? ORDER BY played_at DESC LIMIT 50', [req.user.uid])
  res.json({ items })
})

app.get('/api/health', (_, res) => res.json({ ok: true }))

const port = Number(process.env.PORT || 3000)
async function bootstrap() {
  await ensureDemoUser()
  app.listen(port, () => {
    console.log(`imink mpx server running at http://127.0.0.1:${port}`)
  })
}

bootstrap().catch((e) => {
  console.error('server bootstrap failed', e)
  process.exit(1)
})
