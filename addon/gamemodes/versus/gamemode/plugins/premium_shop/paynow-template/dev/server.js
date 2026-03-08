'use strict'

const express = require('express')
const path = require('path')
const Twig = require('twig')
const schema = require('../schema.json')

const PORT = process.env.PORT || 3000
const TEMPLATE_DIR = path.join(__dirname, '..')

// ---------- Config defaults from schema.json ----------
// PayNow passes toggle values into templates as the strings "true"/"false".
const configDefaults = {}
for (const section of schema.config) {
  for (const opt of section.options) {
    const val = opt.default !== undefined ? opt.default : ''
    configDefaults[opt.id] = typeof val === 'boolean' ? String(val) : val
  }
}

// ---------- Mock store (defined early so filters can close over it) ----------
const mockStore = { name: 'Versus Store', currency: 'USD' }

// ---------- Twig extensions ----------
// Custom filters used by PayNow templates
Twig.extendFilter('money', (value) => {
  const n = parseFloat(value)
  return isNaN(n) ? '0.00' : n.toFixed(2)
})

Twig.extendFilter('money_store_currency', (value) => {
  const n = parseFloat(value)
  return `${isNaN(n) ? '0.00' : n.toFixed(2)} ${mockStore.currency}`
})

Twig.extendFilter('time_diff', (value) => {
  if (!value) return 'unknown'
  const then = new Date(value).getTime()
  if (isNaN(then)) return String(value)
  const diffMs = Date.now() - then
  const future = diffMs < 0
  const abs = Math.abs(diffMs)
  const mins = Math.round(abs / 60000)
  const suffix = future ? 'from now' : 'ago'
  const label = (n, u) => `${n} ${u}${n !== 1 ? 's' : ''} ${suffix}`
  if (mins < 1) return 'just now'
  if (mins < 60) return label(mins, 'minute')
  const hours = Math.round(mins / 60)
  if (hours < 24) return label(hours, 'hour')
  return label(Math.round(hours / 24), 'day')
})

// Custom functions used by PayNow templates
Twig.extendFunction('config', (key) => {
  const val = configDefaults[key]
  return val !== undefined ? val : ''
})

Twig.extendFunction('asset', (filename) => `/${filename}`)

// i18n passthrough — PayNow resolves translations, we just echo the key
Twig.extendFunction('__', (key) => String(key))

// ---------- Express ----------
const app = express()

// Do NOT use Express's view engine — it mangles ".html" in {% extends "layout.html" %}.
// Instead, render via Twig.renderFile directly so Twig resolves includes/extends
// relative to the template directory without any extension stripping.
Twig.cache(false)

function render(res, filename, context, next) {
  Twig.renderFile(path.join(TEMPLATE_DIR, filename), context, (err, html) => {
    if (err) return next(err)
    res.send(html)
  })
}

// Serve static assets (style.css, script.js, fonts, svgs/ etc.) but NOT .html
// files, which must go through the Twig renderer via routes below.
// `index: false` prevents express.static from auto-serving index.html for "/".
app.use((req, res, next) => {
  if (req.path.endsWith('.html')) return next()
  express.static(TEMPLATE_DIR, { index: false })(req, res, next)
})

// ---------- Mock data ----------
const mockCustomer = {
  id: 'cust_mock_123',
  name: 'MockPlayer',
  profile: {
    avatar_url:
      'https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg',
  },
}

const mockNavlinks = [
  { node_id: 'nav_1', name: 'VIP', tag_query: 'vip', children: [] },
  {
    node_id: 'nav_2',
    name: 'Packages',
    tag_query: 'packages',
    children: [
      { node_id: 'nav_2_1', name: 'Starter', tag_query: 'starter', children: [] },
      { node_id: 'nav_2_2', name: 'Premium', tag_query: 'premium', children: [] },
    ],
  },
]

const mockCustomPages = [
  {
    path: '/info',
    title: 'Info',
    icon: 'fa-circle-info',
    settings: false,
    content: '<p>This is a custom informational page.</p>',
  },
]

const mockProducts = [
  {
    slug: 'vip-bronze',
    name: 'VIP Bronze',
    label: '30 days',
    price: 4.99,
    image_url: '',
    description: '<p>Access to bronze VIP features for <strong>30 days</strong>.</p>',
    pricing: { active_sale: null, price_original: 4.99, vat_rate: null },
    stock: { available_to_purchase: true },
    allow_one_time_purchase: true,
    allow_subscription: false,
    is_gifting_disabled: false,
    single_game_server_only: false,
    custom_variables: [],
    gameservers: [],
  },
  {
    slug: 'vip-silver',
    name: 'VIP Silver',
    label: '30 days',
    price: 9.99,
    image_url: '',
    description: '<p>Access to silver VIP features for <strong>30 days</strong>.</p>',
    pricing: { active_sale: { name: 'Summer Sale' }, price_original: 14.99, vat_rate: null },
    stock: { available_to_purchase: true },
    allow_one_time_purchase: true,
    allow_subscription: true,
    is_gifting_disabled: false,
    single_game_server_only: true,
    custom_variables: [],
    gameservers: [
      { id: 'gs_1', name: 'EU Main' },
      { id: 'gs_2', name: 'US East' },
    ],
  },
  {
    slug: 'vip-gold',
    name: 'VIP Gold',
    label: 'Permanent',
    price: 24.99,
    image_url: '',
    description: '<p>Permanent access to all gold VIP features.</p>',
    pricing: {
      active_sale: null,
      price_original: 24.99,
      vat_rate: { percentage: 21, vat_abbreviation: 'VAT' },
    },
    stock: { available_to_purchase: true },
    allow_one_time_purchase: true,
    allow_subscription: false,
    is_gifting_disabled: false,
    single_game_server_only: false,
    custom_variables: [
      {
        name: 'Discord Username',
        identifier: 'discord_username',
        type: 'text',
        description: 'Enter your Discord username',
        value_regex: '',
        options: [],
      },
      {
        name: 'Preferred Role',
        identifier: 'role',
        type: 'dropdown',
        description: 'Pick a role',
        value_regex: '',
        options: [
          { value: 'builder', name: 'Builder' },
          { value: 'fighter', name: 'Fighter' },
        ],
      },
    ],
    gameservers: [],
  },
  {
    slug: 'out-of-stock',
    name: 'Sold Out Pack',
    label: '',
    price: 19.99,
    image_url: '',
    description: '<p>This item is currently sold out.</p>',
    pricing: { active_sale: null, price_original: 19.99, vat_rate: null },
    stock: { available_to_purchase: false },
    allow_one_time_purchase: true,
    allow_subscription: false,
    is_gifting_disabled: false,
    single_game_server_only: false,
    custom_variables: [],
    gameservers: [],
  },
]

const mockCartLines = [
  {
    slug: 'vip-bronze',
    name: 'VIP Bronze',
    image_url: '',
    price: 4.99,
    quantity: 2,
    selected_gameserver: null,
  },
  {
    slug: 'vip-silver',
    name: 'VIP Silver',
    image_url: '',
    price: 9.99,
    quantity: 1,
    selected_gameserver: { name: 'EU Main' },
  },
]

const mockCart = {
  lines: mockCartLines,
  total: mockCartLines.reduce((sum, l) => sum + l.price * l.quantity, 0),
}

const mockEmptyCart = { lines: [], total: 0 }

// ---------- Context builder ----------
// All pages share this base. Extra properties override the defaults.
function ctx(reqPath, extra = {}) {
  return {
    store: mockStore,
    customer: mockCustomer,
    cart: mockCart,
    navlinks: mockNavlinks,
    activeRootNavlink: null,
    activeNavlink: null,
    custom_pages: mockCustomPages,
    modules: '',
    notification: null,
    favicon: '',
    // PayNow fills template.index from the rich-text config field
    template: { index: configDefaults.index || '<p>Welcome to the store!</p>' },
    request: { path: reqPath },
    auth_provider: 'steam',
    ...extra,
  }
}

// Helpers for readable relative timestamps
const hoursAgo = (h) => new Date(Date.now() - 3600000 * h).toISOString()
const daysAgo = (d) => new Date(Date.now() - 3600000 * 24 * d).toISOString()
const daysFromNow = (d) => new Date(Date.now() + 3600000 * 24 * d).toISOString()

// ---------- Routes ----------

// Home
app.get('/', (req, res, next) => render(res, 'index.html', ctx('/'), next))

// Category / product listing
app.get('/products', (req, res, next) => {
  const tag = req.query.tag || 'vip'
  render(res, 'category.html', ctx('/products', {
    products: mockProducts,
    activeTag: {
      name: tag.toUpperCase(),
      description: `Browse our <strong>${tag}</strong> products.`,
    },
    activeRootNavlink: mockNavlinks.find((n) => n.tag_query === tag) || mockNavlinks[0],
  }), next)
})

// Product detail
app.get('/products/:slug', (req, res, next) => {
  const product = mockProducts.find((p) => p.slug === req.params.slug) || mockProducts[0]
  render(res, 'product.html', ctx(`/products/${req.params.slug}`, { product }), next)
})

// Cart (with items)
app.get('/cart', (req, res, next) => render(res, 'cart.html', ctx('/cart'), next))

// Cart (empty) — for testing the empty-cart state
app.get('/cart/empty-preview', (req, res, next) =>
  render(res, 'cart.html', ctx('/cart', { cart: mockEmptyCart }), next)
)

// Account — orders
app.get('/account', (req, res, next) => {
  render(res, 'account.html', ctx('/account', {
    account_view: 'orders',
    orders: [
      {
        pretty_id: 'ORD-001',
        total_amount_str: '$9.99',
        is_subscription: false,
        completed_at: hoursAgo(5),
        subscription_id: null,
        billing_cycle_sequence: null,
        lines: [{ product_name: 'VIP Silver', product_image_url: '' }],
      },
      {
        pretty_id: 'ORD-002',
        total_amount_str: '$4.99',
        is_subscription: true,
        completed_at: daysAgo(3),
        subscription_id: 'sub_1',
        billing_cycle_sequence: 2,
        lines: [{ product_name: 'VIP Bronze', product_image_url: '' }],
      },
    ],
  }), next)
})

// Account — subscriptions list
app.get('/account/subscriptions', (req, res, next) => {
  render(res, 'account.html', ctx('/account/subscriptions', {
    account_view: 'subscriptions',
    subscriptions: [
      {
        id: 'sub_1',
        pretty_id: 'SUB-001',
        product_name: 'VIP Silver',
        product_image_url: '',
        status: 'active',
        active_at: daysAgo(10),
        canceled_at: null,
        current_period_end: daysFromNow(20),
        total_amount_str: '$9.99',
        interval_value: 1,
        interval_scale: 'month',
      },
    ],
  }), next)
})

// Account — subscription detail (shows canceled state)
app.get('/account/subscriptions/:id', (req, res, next) => {
  const sub = {
    id: req.params.id,
    pretty_id: 'SUB-001',
    product_name: 'VIP Silver',
    product_image_url: '',
    status: 'canceled',
    active_at: daysAgo(30),
    canceled_at: daysAgo(2),
    current_period_end: daysAgo(2),
    total_amount_str: '$9.99',
    interval_value: 1,
    interval_scale: 'month',
  }
  render(res, 'account.html', ctx(`/account/subscriptions/${req.params.id}`, {
    account_view: 'subscription-detail',
    subscription: sub,
    subscriptions: [sub],
  }), next)
})

// Account — inventory items
app.get('/account/inventory-items', (req, res, next) => {
  render(res, 'account.html', ctx('/account/inventory-items', {
    account_view: 'inventory-items',
    inventory_items: [
      {
        product: { name: 'VIP Bronze' },
        state: 'active',
        active_at: daysAgo(5),
        added_at: null,
        removed_at: null,
        expires_at: daysFromNow(25),
        subscription_id: null,
      },
      {
        product: { name: 'VIP Silver' },
        state: 'expired',
        active_at: daysAgo(35),
        added_at: null,
        removed_at: daysAgo(5),
        expires_at: daysAgo(5),
        subscription_id: 'sub_1',
      },
    ],
  }), next)
})

// Auth — sign in (not logged in, so customer is null/guest)
app.get('/auth/sign-in', (req, res, next) =>
  render(res, 'auth_username.html', { ...ctx('/auth/sign-in'), customer: null }, next)
)

app.get('/auth/sign-out', (req, res) => res.redirect('/'))

// Order complete
app.get('/complete', (req, res, next) =>
  render(res, 'complete.html', ctx('/complete', {
    complete: {
      text:
        '<p>Thank you for your purchase!</p><p>Your items will be activated shortly.</p>',
    },
  }), next)
)

// Custom page (from mockCustomPages)
app.get('/info', (req, res, next) =>
  render(res, 'custom_page.html', ctx('/info', {
    title: 'Info',
    content: mockCustomPages[0].content,
  }), next)
)

// Legal pages
app.get('/legal/:page', (req, res, next) =>
  render(res, 'custom_page.html', ctx(`/legal/${req.params.page}`, {
    title: req.params.page
      .replace(/-/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase()),
    content: '<p>Legal content goes here.</p>',
  }), next)
)

// ---------- Start ----------
app.listen(PORT, () => {
  const base = `http://localhost:${PORT}`
  console.log(`\n  PayNow template dev server → ${base}\n`)
  const routes = [
    ['Home', '/'],
    ['Category', '/products?tag=vip'],
    ['Product (bronze)', '/products/vip-bronze'],
    ['Product (silver, sale)', '/products/vip-silver'],
    ['Product (gold, custom vars)', '/products/vip-gold'],
    ['Product (out of stock)', '/products/out-of-stock'],
    ['Cart', '/cart'],
    ['Cart (empty)', '/cart/empty-preview'],
    ['Account — orders', '/account'],
    ['Account — subscriptions', '/account/subscriptions'],
    ['Account — sub detail', '/account/subscriptions/sub_1'],
    ['Account — items', '/account/inventory-items'],
    ['Sign in', '/auth/sign-in'],
    ['Order complete', '/complete'],
    ['Custom page', '/info'],
    ['Legal', '/legal/privacy-policy'],
  ]
  for (const [name, p] of routes) {
    console.log(`    ${name.padEnd(26)} ${base}${p}`)
  }
  console.log()
})
