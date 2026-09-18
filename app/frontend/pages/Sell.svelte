<script>
  import { router } from '@inertiajs/svelte'
  import Navbar from '../components/Navbar.svelte'
  import { formatMoney, formatDate, generateIdempotencyKey } from '../lib/utils'

  let { current_shift = null, catalog = [], recent_orders = [] } = $props()

  // Svelte 5 Runes for state
  let activeTab = $state('all') // 'all' | 'grocery' | 'food' | 'carwash'
  let searchQuery = $state('')
  let cart = $state([]) // [{ id, catalog_id, name, sku, qty, unit, unit_price_cents, vertical, modifiers }]
  let activeOrder = $state(null) // Order record created on backend
  let isTenderModalOpen = $state(false)
  let tenderMethod = $state('cash') // 'cash' | 'wallet'
  let cashAmountTendered = $state(0)
  let walletCustomerId = $state('')
  let walletPin = $state('')
  let isProcessing = $state(false)
  let notification = $state(null)

  // Filtered catalog
  let filteredCatalog = $derived(
    catalog.filter(item => {
      const matchTab = activeTab === 'all' || item.vertical === activeTab
      const matchSearch = item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                          item.sku.toLowerCase().includes(searchQuery.toLowerCase())
      return matchTab && matchSearch
    })
  )

  // Cart calculations
  let cartTotalCents = $derived(
    cart.reduce((sum, line) => sum + Math.round(Number(line.qty) * Number(line.unit_price_cents)), 0)
  )

  let remainingDueCents = $derived.by(() => {
    if (!activeOrder) return cartTotalCents
    const captured = (activeOrder.tenders || [])
      .filter(t => t.status === 'captured')
      .reduce((s, t) => s + Number(t.amount_cents), 0)
    return Math.max(0, activeOrder.total_cents - captured)
  })

  let cashChangeDue = $derived(
    Math.max(0, cashAmountTendered - remainingDueCents)
  )

  function showNotification(text, type = 'success') {
    notification = { text, type }
    setTimeout(() => {
      notification = null
    }, 4000)
  }

  function addToCart(item) {
    const existingIndex = cart.findIndex(c => c.catalog_id === item.id)
    if (existingIndex >= 0) {
      const step = item.step || (item.unit === 'kg' ? 0.1 : 1)
      cart[existingIndex].qty = +(cart[existingIndex].qty + step).toFixed(3)
    } else {
      let initialQty = item.unit === 'kg' ? 1.0 : 1
      let defaultModifiers = {}
      if (item.vertical === 'food' && item.modifiers) {
        item.modifiers.forEach(mod => {
          if (mod.options && mod.options.length > 0) {
            defaultModifiers[mod.name] = mod.options[0]
          }
        })
      }
      if (item.vertical === 'carwash') {
        defaultModifiers['tier'] = item.tier || 'standard'
      }

      cart.push({
        id: 'cart-' + Math.random().toString(36).substring(2, 9),
        catalog_id: item.id,
        name: item.name,
        sku: item.sku,
        qty: initialQty,
        unit: item.unit || 'item',
        unit_price_cents: item.unit_price_cents,
        vertical: item.vertical,
        step: item.step || (item.unit === 'kg' ? 0.1 : 1),
        modifiers: defaultModifiers
      })
    }
  }

  function updateQty(index, newQty) {
    const val = Number(newQty)
    if (val <= 0) {
      removeFromCart(index)
    } else {
      cart[index].qty = +val.toFixed(3)
    }
  }

  function removeFromCart(index) {
    cart.splice(index, 1)
  }

  function clearCart() {
    cart = []
    activeOrder = null
  }

  // Simulate digital scale reading (Web Serial Scale API)
  function simulateScaleWeigh(index) {
    const weights = [0.45, 0.82, 1.25, 1.64, 2.10]
    const weight = weights[Math.floor(Math.random() * weights.length)]
    cart[index].qty = weight
    showNotification(`Timbangan Digital: ${cart[index].name} terdeteksi ${weight} kg`, 'info')
  }

  async function handleCheckout() {
    if (cart.length === 0) return
    isProcessing = true

    // Determine vertical: if mixed, use first item's vertical or 'grocery'
    const vertical = cart[0].vertical || 'grocery'
    const payload = {
      station_ref: 'Station-01',
      vertical: vertical,
      lines: cart.map(c => ({
        name: c.name,
        sku: c.sku,
        qty: c.qty,
        unit: c.unit,
        unit_price_cents: c.unit_price_cents,
        modifiers: c.modifiers
      }))
    }

    try {
      const res = await fetch('/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      })

      const data = await res.json()
      if (res.ok && data.success) {
        activeOrder = data.order
        cashAmountTendered = remainingDueCents
        isTenderModalOpen = true
        showNotification('Order berhasil dibuat! Siap diproses bayar.', 'success')
      } else {
        showNotification(data.error || 'Gagal membuat order', 'error')
      }
    } catch (e) {
      showNotification('Kesalahan jaringan saat checkout', 'error')
    } finally {
      isProcessing = false
    }
  }

  async function submitTender() {
    if (!activeOrder) return

    if (tenderMethod === 'cash' && cashAmountTendered <= 0) {
      showNotification('Nominal tunai harus lebih besar dari 0', 'error')
      return
    }

    isProcessing = true

    const amount = tenderMethod === 'cash' ? Math.min(cashAmountTendered, remainingDueCents) : remainingDueCents
    const idempotencyKey = generateIdempotencyKey()

    const payload = {
      method: tenderMethod,
      amount_cents: amount,
      idempotency_key: idempotencyKey,
      customer_id: walletCustomerId,
      pin: walletPin
    }

    try {
      const res = await fetch(`/orders/${activeOrder.id}/tenders`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(payload)
      })

      const data = await res.json()
      if (res.ok && data.success) {
        activeOrder = data.order
        showNotification(`Pembayaran ${tenderMethod === 'cash' ? 'Tunai' : 'omniWallet'} sukses dicatat!`, 'success')

        if (activeOrder.status === 'paid') {
          setTimeout(() => {
            clearCart()
            isTenderModalOpen = false
            router.reload()
          }, 2000)
        }
      } else {
        showNotification(data.error || 'Gagal memproses pembayaran', 'error')
      }
    } catch (e) {
      showNotification('Gagal menghubungi engine pembayaran', 'error')
    } finally {
      isProcessing = false
    }
  }
</script>

<div class="min-h-screen bg-gray-900 text-gray-100 flex flex-col font-sans">
  <Navbar active="sell" {current_shift} />

  <!-- Flash Notification -->
  {#if notification}
    <div class="fixed top-16 right-6 z-50 px-4 py-3 rounded-lg shadow-xl text-sm font-medium border flex items-center space-x-2 transition-all {notification.type === 'error' ? 'bg-red-950 border-red-700 text-red-200' : notification.type === 'info' ? 'bg-blue-950 border-blue-700 text-blue-200' : 'bg-emerald-950 border-emerald-700 text-emerald-200'}">
      <span>{notification.type === 'error' ? '⚠️' : '✓'}</span>
      <span>{notification.text}</span>
    </div>
  {/if}

  <div class="flex-1 flex overflow-hidden">
    <!-- Left: Catalog & Vertical Selector (65%) -->
    <main class="flex-1 flex flex-col p-6 overflow-y-auto border-r border-gray-800">
      <!-- Search & Filters -->
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div class="flex items-center space-x-2 bg-gray-800 p-1 rounded-xl border border-gray-700">
          <button
            onclick={() => activeTab = 'all'}
            class="px-4 py-2 rounded-lg text-xs font-semibold uppercase tracking-wider transition {activeTab === 'all' ? 'bg-emerald-600 text-white shadow' : 'text-gray-400 hover:text-white'}"
          >
            Semua Menu
          </button>
          <button
            onclick={() => activeTab = 'grocery'}
            class="px-4 py-2 rounded-lg text-xs font-semibold uppercase tracking-wider transition {activeTab === 'grocery' ? 'bg-emerald-600 text-white shadow' : 'text-gray-400 hover:text-white'}"
          >
            🛒 Grocery (Scale)
          </button>
          <button
            onclick={() => activeTab = 'food'}
            class="px-4 py-2 rounded-lg text-xs font-semibold uppercase tracking-wider transition {activeTab === 'food' ? 'bg-emerald-600 text-white shadow' : 'text-gray-400 hover:text-white'}"
          >
            🍳 Food & Modifiers
          </button>
          <button
            onclick={() => activeTab = 'carwash'}
            class="px-4 py-2 rounded-lg text-xs font-semibold uppercase tracking-wider transition {activeTab === 'carwash' ? 'bg-emerald-600 text-white shadow' : 'text-gray-400 hover:text-white'}"
          >
            🚗 Carwash (Tiers)
          </button>
        </div>

        <div class="relative w-full md:w-72">
          <input
            type="text"
            bind:value={searchQuery}
            placeholder="Cari produk atau SKU..."
            class="w-full bg-gray-800 border border-gray-700 rounded-xl px-4 py-2 text-sm text-gray-200 placeholder-gray-500 focus:outline-none focus:border-emerald-500"
          />
          {#if searchQuery}
            <button
              onclick={() => searchQuery = ''}
              class="absolute right-3 top-2.5 text-xs text-gray-500 hover:text-gray-300"
            >
              ✕
            </button>
          {/if}
        </div>
      </div>

      <!-- Catalog Grid -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {#each filteredCatalog as item (item.id)}
          <div
            class="bg-gray-800 border border-gray-700/80 hover:border-emerald-500/60 rounded-xl p-4 transition-all duration-200 flex flex-col justify-between shadow-sm hover:shadow-emerald-950/20 group"
          >
            <div>
              <div class="flex items-start justify-between">
                <span class="text-xs font-mono text-gray-400 px-2 py-0.5 rounded bg-gray-900 border border-gray-700">
                  {item.sku}
                </span>
                <span class="text-[10px] font-bold uppercase tracking-widest px-2 py-0.5 rounded {item.vertical === 'grocery' ? 'bg-amber-950 text-amber-300 border border-amber-800' : item.vertical === 'food' ? 'bg-indigo-950 text-indigo-300 border border-indigo-800' : 'bg-cyan-950 text-cyan-300 border border-cyan-800'}">
                  {item.vertical}
                </span>
              </div>
              <h3 class="text-base font-bold text-gray-100 mt-2 group-hover:text-emerald-400 transition">
                {item.name}
              </h3>
              {#if item.category}
                <p class="text-xs text-gray-400 mt-0.5">{item.category}</p>
              {/if}

              <!-- Modifiers/Tier Info -->
              {#if item.modifiers}
                <div class="flex flex-wrap gap-1 mt-2">
                  {#each item.modifiers as mod}
                    <span class="text-[10px] bg-gray-900/80 text-gray-300 px-1.5 py-0.5 rounded border border-gray-700">
                      {mod.name}
                    </span>
                  {/each}
                </div>
              {/if}
              {#if item.tier}
                <div class="mt-2">
                  <span class="text-[10px] uppercase font-bold bg-cyan-950 text-cyan-400 px-2 py-0.5 rounded border border-cyan-800">
                    Tier: {item.tier}
                  </span>
                </div>
              {/if}
            </div>

            <div class="mt-4 pt-3 border-t border-gray-700/50 flex items-center justify-between">
              <div>
                <span class="text-xs text-gray-400">Harga / {item.unit}:</span>
                <p class="text-lg font-black text-emerald-400">
                  {formatMoney(item.unit_price_cents)}
                </p>
              </div>
              <button
                onclick={() => addToCart(item)}
                class="bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold px-3.5 py-2 rounded-lg transition active:scale-95 shadow"
              >
                + Tambah
              </button>
            </div>
          </div>
        {/each}
      </div>

      <!-- Recent Orders Bar -->
      <section class="mt-8 pt-6 border-t border-gray-800">
        <h4 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">
          10 Transaksi Terakhir di Stasiun Ini
        </h4>
        <div class="flex space-x-3 overflow-x-auto pb-2">
          {#each recent_orders as ro}
            <div class="flex-shrink-0 bg-gray-800 border border-gray-700 rounded-lg p-3 min-w-[200px] text-xs">
              <div class="flex justify-between items-center mb-1">
                <span class="font-mono text-gray-400">#{ro.id.substring(0, 8)}</span>
                <span class="px-1.5 py-0.5 rounded text-[10px] font-bold uppercase {ro.status === 'paid' || ro.status === 'fulfilled' ? 'bg-emerald-950 text-emerald-400' : ro.status === 'voided' ? 'bg-red-950 text-red-400' : 'bg-amber-950 text-amber-400'}">
                  {ro.status}
                </span>
              </div>
              <p class="font-bold text-gray-200">{formatMoney(ro.total_cents)}</p>
              <p class="text-[10px] text-gray-500">{formatDate(ro.created_at)}</p>
            </div>
          {:else}
            <p class="text-xs text-gray-500 italic">Belum ada transaksi di stasiun ini hari ini.</p>
          {/each}
        </div>
      </section>
    </main>

    <!-- Right: Active Cart & Multi-Tender Panel (35%) -->
    <aside class="w-full md:w-96 lg:w-[420px] bg-gray-850 flex flex-col justify-between border-l border-gray-800">
      <!-- Cart Header -->
      <div class="p-4 border-b border-gray-800 flex items-center justify-between bg-gray-800/40">
        <div>
          <h2 class="text-base font-bold text-white flex items-center space-x-2">
            <span>🧾 Tiket Transaksi</span>
          </h2>
          <p class="text-xs text-gray-400">{cart.length} item dalam pesanan</p>
        </div>
        {#if cart.length > 0}
          <button
            onclick={clearCart}
            class="text-xs text-red-400 hover:text-red-300 font-medium px-2 py-1 rounded hover:bg-red-950/40 transition"
          >
            Hapus Semua
          </button>
        {/if}
      </div>

      <!-- Line Items List -->
      <div class="flex-1 overflow-y-auto p-4 space-y-3">
        {#each cart as line, index (line.id)}
          <div class="bg-gray-800 border border-gray-700/70 rounded-xl p-3 text-sm">
            <div class="flex justify-between items-start">
              <div>
                <h4 class="font-bold text-gray-200 text-sm">{line.name}</h4>
                <p class="text-xs text-gray-400 font-mono">
                  {formatMoney(line.unit_price_cents)} / {line.unit}
                </p>
              </div>
              <button
                onclick={() => removeFromCart(index)}
                class="text-gray-500 hover:text-red-400 text-xs px-1"
              >
                ✕
              </button>
            </div>

            <!-- Modifiers configuration for Food -->
            {#if line.vertical === 'food' && Object.keys(line.modifiers).length > 0}
              <div class="mt-2 space-y-1 bg-gray-900/60 p-2 rounded-lg text-xs">
                {#each Object.entries(line.modifiers) as [modName, modVal]}
                  <div class="flex justify-between text-gray-400 text-[11px]">
                    <span>{modName}:</span>
                    <span class="font-semibold text-emerald-400">{modVal}</span>
                  </div>
                {/each}
              </div>
            {/if}

            <!-- Vehicle Tier for Carwash -->
            {#if line.vertical === 'carwash'}
              <div class="mt-2 bg-gray-900/60 p-2 rounded-lg text-xs flex justify-between">
                <span class="text-gray-400">Kategori Cuci:</span>
                <span class="font-bold uppercase text-cyan-400">{line.modifiers.tier || 'Standard'}</span>
              </div>
            {/if}

            <!-- Stepper and digital weigh scale integration -->
            <div class="mt-3 pt-2 border-t border-gray-700/50 flex items-center justify-between">
              <div class="flex items-center space-x-1">
                <button
                  onclick={() => updateQty(index, line.qty - line.step)}
                  class="w-7 h-7 rounded bg-gray-700 hover:bg-gray-600 text-white font-bold text-xs flex items-center justify-center transition"
                >
                  -
                </button>
                <input
                  type="number"
                  step={line.step}
                  value={line.qty}
                  oninput={(e) => updateQty(index, e.target.value)}
                  class="w-16 bg-gray-900 border border-gray-700 rounded text-center py-1 text-xs font-mono text-gray-200 focus:outline-none focus:border-emerald-500"
                />
                <button
                  onclick={() => updateQty(index, line.qty + line.step)}
                  class="w-7 h-7 rounded bg-gray-700 hover:bg-gray-600 text-white font-bold text-xs flex items-center justify-center transition"
                >
                  +
                </button>
                <span class="text-xs text-gray-400 ml-1">{line.unit}</span>

                {#if line.unit === 'kg'}
                  <button
                    onclick={() => simulateScaleWeigh(index)}
                    title="Baca Timbangan Digital Web Serial"
                    class="ml-2 bg-amber-950 border border-amber-700 hover:bg-amber-900 text-amber-300 text-[10px] font-bold px-2 py-1 rounded transition"
                  >
                    ⚖️ Timbang
                  </button>
                {/if}
              </div>

              <div class="text-right">
                <span class="font-bold text-sm text-gray-100">
                  {formatMoney(Math.round(line.qty * line.unit_price_cents))}
                </span>
              </div>
            </div>
          </div>
        {:else}
          <div class="h-64 flex flex-col items-center justify-center text-center text-gray-500 p-6">
            <span class="text-4xl mb-3 opacity-40">🛒</span>
            <p class="font-medium text-sm">Tiket Transaksi Masih Kosong</p>
            <p class="text-xs text-gray-600 mt-1">Pilih menu dari katalog di sebelah kiri untuk memulai penjualan.</p>
          </div>
        {/each}
      </div>

      <!-- Checkout Footer -->
      <div class="p-4 bg-gray-800 border-t border-gray-700 space-y-3">
        <div class="flex justify-between items-center text-sm text-gray-400">
          <span>Subtotal</span>
          <span class="font-mono text-gray-200">{formatMoney(cartTotalCents)}</span>
        </div>
        <div class="flex justify-between items-center text-lg font-black text-white pt-2 border-t border-gray-700">
          <span>Total Tagihan</span>
          <span class="text-emerald-400">{formatMoney(cartTotalCents)}</span>
        </div>

        {#if !current_shift}
          <div class="p-2.5 rounded-lg bg-amber-950/60 border border-amber-800 text-amber-300 text-xs flex items-start space-x-2">
            <span>⚠️</span>
            <span>Shift kasir belum dibuka. Buka shift di menu Shift untuk mencatat kas.</span>
          </div>
        {/if}

        <button
          onclick={handleCheckout}
          disabled={cart.length === 0 || isProcessing}
          class="w-full py-3.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold rounded-xl text-base shadow-lg shadow-emerald-950/30 transition flex items-center justify-center space-x-2"
        >
          <span>{isProcessing ? 'Memproses...' : 'Bayar / Tender'}</span>
          <span>→</span>
        </button>
      </div>
    </aside>
  </div>

  <!-- Multi-Tender Modal -->
  {#if isTenderModalOpen && activeOrder}
    <div class="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-gray-800 border border-gray-700 rounded-2xl w-full max-w-xl overflow-hidden shadow-2xl flex flex-col">
        <!-- Modal Header -->
        <div class="p-5 border-b border-gray-700 flex items-center justify-between bg-gray-850">
          <div>
            <h3 class="text-lg font-bold text-white">Pembayaran (Multi-Tender)</h3>
            <p class="text-xs text-gray-400 font-mono">Order ID: #{activeOrder.id.substring(0, 8)}</p>
          </div>
          <button
            onclick={() => isTenderModalOpen = false}
            class="text-gray-400 hover:text-white text-lg font-bold px-2 py-1"
          >
            ✕
          </button>
        </div>

        <!-- Balance Info Banner -->
        <div class="p-5 bg-gray-900 border-b border-gray-700 grid grid-cols-3 gap-3 text-center">
          <div class="bg-gray-800 p-3 rounded-xl border border-gray-700">
            <span class="text-[10px] uppercase font-bold text-gray-400">Total Nota</span>
            <p class="text-base font-bold text-gray-200 mt-0.5">{formatMoney(activeOrder.total_cents)}</p>
          </div>
          <div class="bg-gray-800 p-3 rounded-xl border border-gray-700">
            <span class="text-[10px] uppercase font-bold text-gray-400">Sudah Bayar</span>
            <p class="text-base font-bold text-emerald-400 mt-0.5">{formatMoney(activeOrder.total_cents - remainingDueCents)}</p>
          </div>
          <div class="bg-gray-800 p-3 rounded-xl border border-gray-700">
            <span class="text-[10px] uppercase font-bold text-gray-400">Sisa Tagihan</span>
            <p class="text-base font-bold text-amber-400 mt-0.5">{formatMoney(remainingDueCents)}</p>
          </div>
        </div>

        <!-- Payment Method Tabs -->
        <div class="p-5 flex-1 space-y-4">
          <div class="grid grid-cols-2 gap-2 bg-gray-900 p-1 rounded-xl border border-gray-700">
            <button
              onclick={() => tenderMethod = 'cash'}
              class="py-2 text-xs font-bold rounded-lg transition {tenderMethod === 'cash' ? 'bg-emerald-600 text-white' : 'text-gray-400 hover:text-white'}"
            >
              💵 Tunai (Cash)
            </button>
            <button
              onclick={() => tenderMethod = 'wallet'}
              class="py-2 text-xs font-bold rounded-lg transition {tenderMethod === 'wallet' ? 'bg-emerald-600 text-white' : 'text-gray-400 hover:text-white'}"
            >
              📱 omniWallet (QR / PIN)
            </button>
          </div>

          {#if tenderMethod === 'cash'}
            <div class="space-y-4">
              <div>
                <label for="cashAmountInput" class="block text-xs font-medium text-gray-400 mb-1">Nominal Diterima Kasir:</label>
                <input
                  id="cashAmountInput"
                  type="number"
                  bind:value={cashAmountTendered}
                  class="w-full bg-gray-900 border border-gray-700 rounded-xl px-4 py-2.5 text-lg font-mono font-bold text-white focus:outline-none focus:border-emerald-500"
                />
              </div>

              <!-- Quick cash buttons -->
              <div class="grid grid-cols-4 gap-2">
                <button
                  onclick={() => cashAmountTendered = remainingDueCents}
                  class="py-2 bg-gray-700 hover:bg-gray-600 text-xs font-bold rounded-lg text-emerald-300"
                >
                  Uang Pas
                </button>
                <button
                  onclick={() => cashAmountTendered = 50_000}
                  class="py-2 bg-gray-700 hover:bg-gray-600 text-xs font-bold rounded-lg text-white"
                >
                  50.000
                </button>
                <button
                  onclick={() => cashAmountTendered = 100_000}
                  class="py-2 bg-gray-700 hover:bg-gray-600 text-xs font-bold rounded-lg text-white"
                >
                  100.000
                </button>
                <button
                  onclick={() => cashAmountTendered = 200_000}
                  class="py-2 bg-gray-700 hover:bg-gray-600 text-xs font-bold rounded-lg text-white"
                >
                  200.000
                </button>
              </div>

              {#if cashChangeDue > 0}
                <div class="p-3 bg-emerald-950 border border-emerald-700 rounded-xl text-emerald-300 flex justify-between items-center">
                  <span class="text-xs font-bold uppercase">Kembalian Kasir:</span>
                  <span class="text-lg font-black font-mono">{formatMoney(cashChangeDue)}</span>
                </div>
              {/if}
            </div>
          {:else}
            <!-- omniWallet tender -->
            <div class="space-y-3">
              <div>
                <label for="walletCustomerId" class="block text-xs font-medium text-gray-400 mb-1">Customer ID / Nomor Wallet:</label>
                <input
                  id="walletCustomerId"
                  type="text"
                  bind:value={walletCustomerId}
                  placeholder="contoh: cust-12345"
                  class="w-full bg-gray-900 border border-gray-700 rounded-xl px-4 py-2 text-sm font-mono text-white focus:outline-none focus:border-emerald-500"
                />
              </div>
              <div>
                <label for="walletPin" class="block text-xs font-medium text-gray-400 mb-1">6-Digit PIN Otorisasi:</label>
                <input
                  id="walletPin"
                  type="password"
                  maxlength="6"
                  bind:value={walletPin}
                  placeholder="••••••"
                  class="w-full bg-gray-900 border border-gray-700 rounded-xl px-4 py-2 text-sm font-mono text-center tracking-widest text-white focus:outline-none focus:border-emerald-500"
                />
              </div>
              <p class="text-[11px] text-gray-500">
                Terhubung langsung ke omniWallet Double-Entry Core Engine via Signed HMAC HTTP Client.
              </p>
            </div>
          {/if}

          <!-- Captured tenders history on this order -->
          {#if activeOrder.tenders && activeOrder.tenders.length > 0}
            <div class="mt-4 pt-3 border-t border-gray-700">
              <h5 class="text-xs font-bold text-gray-400 uppercase mb-2">Tender Tercatat:</h5>
              <div class="space-y-1">
                {#each activeOrder.tenders as tender}
                  <div class="flex justify-between text-xs bg-gray-900 p-2 rounded border border-gray-700">
                    <span class="font-bold uppercase text-emerald-400">{tender.method}</span>
                    <span class="font-mono text-gray-300">{formatMoney(tender.amount_cents)}</span>
                    <span class="text-[10px] text-gray-500 font-mono">ID: #{tender.id.substring(0, 6)}</span>
                  </div>
                {/each}
              </div>
            </div>
          {/if}
        </div>

        <!-- Modal Footer -->
        <div class="p-5 bg-gray-850 border-t border-gray-700 flex items-center justify-between">
          <button
            onclick={() => isTenderModalOpen = false}
            class="px-4 py-2.5 text-xs font-bold text-gray-400 hover:text-white rounded-lg hover:bg-gray-700 transition"
          >
            Tutup
          </button>
          <button
            onclick={submitTender}
            disabled={isProcessing || (tenderMethod === 'wallet' && !walletCustomerId)}
            class="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold rounded-xl text-sm transition flex items-center space-x-2"
          >
            <span>{isProcessing ? 'Memproses Tender...' : 'Konfirmasi Tender'}</span>
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>
