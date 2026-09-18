<script>
  import Navbar from '../components/Navbar.svelte'
  import { formatMoney, formatDate } from '../lib/utils'

  let { orders = [], filters = {} } = $props()

  // Svelte 5 Runes
  let statusFilter = $state('all')
  let verticalFilter = $state('all')
  let isVoidModalOpen = $state(false)
  let orderToVoid = $state(null)
  let voidReason = $state('Pelanggan membatalkan pesanan')
  let isProcessing = $state(false)
  let notification = $state(null)

  $effect(() => {
    if (filters && filters.status) statusFilter = filters.status
    if (filters && filters.vertical) verticalFilter = filters.vertical
  })

  function showNotification(text, type = 'success') {
    notification = { text, type }
    setTimeout(() => {
      notification = null
    }, 4000)
  }

  let filteredOrders = $derived(
    orders.filter(order => {
      const matchStatus = statusFilter === 'all' || order.status === statusFilter
      const matchVertical = verticalFilter === 'all' || order.vertical === verticalFilter
      return matchStatus && matchVertical
    })
  )

  async function handleFulfill(orderId) {
    isProcessing = true
    try {
      const res = await fetch(`/orders/${orderId}/fulfill`, {
        method: 'POST',
        headers: { 'Accept': 'application/json' }
      })
      const data = await res.json()
      if (res.ok && data.success) {
        showNotification('Order berhasil diproses ke dapur/bay cuci!', 'success')
        window.location.reload()
      } else {
        showNotification(data.error || 'Gagal memenuhi order', 'error')
      }
    } catch (e) {
      showNotification('Kesalahan jaringan saat memproses pesanan', 'error')
    } finally {
      isProcessing = false
    }
  }

  async function handleComplete(orderId) {
    isProcessing = true
    try {
      const res = await fetch(`/orders/${orderId}/complete`, {
        method: 'POST',
        headers: { 'Accept': 'application/json' }
      })
      const data = await res.json()
      if (res.ok && data.success) {
        showNotification('Order selesai diserahkan kepada pelanggan!', 'success')
        window.location.reload()
      } else {
        showNotification(data.error || 'Gagal menyelesaikan order', 'error')
      }
    } catch (e) {
      showNotification('Kesalahan jaringan', 'error')
    } finally {
      isProcessing = false
    }
  }

  function openVoidModal(order) {
    orderToVoid = order
    voidReason = 'Pelanggan membatalkan pesanan'
    isVoidModalOpen = true
  }

  async function submitVoid() {
    if (!orderToVoid) return
    isProcessing = true
    try {
      const res = await fetch(`/orders/${orderToVoid.id}/void`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ reason: voidReason })
      })
      const data = await res.json()
      if (res.ok && data.success) {
        showNotification('Order berhasil dibatalkan (void). Audit log tercatat.', 'success')
        isVoidModalOpen = false
        window.location.reload()
      } else {
        showNotification(data.error || 'Gagal membatalkan order', 'error')
      }
    } catch (e) {
      showNotification('Kesalahan jaringan', 'error')
    } finally {
      isProcessing = false
    }
  }
</script>

<div class="min-h-screen bg-gray-900 text-gray-100 flex flex-col font-sans">
  <Navbar active="orders" />

  <!-- Flash Notification -->
  {#if notification}
    <div class="fixed top-16 right-6 z-50 px-4 py-3 rounded-lg shadow-xl text-sm font-medium border flex items-center space-x-2 transition-all {notification.type === 'error' ? 'bg-red-950 border-red-700 text-red-200' : 'bg-emerald-950 border-emerald-700 text-emerald-200'}">
      <span>{notification.type === 'error' ? '⚠️' : '✓'}</span>
      <span>{notification.text}</span>
    </div>
  {/if}

  <main class="flex-1 p-6 max-w-7xl w-full mx-auto space-y-6">
    <!-- Header & Statistics -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-black text-white">Daftar Pesanan & Antrean</h1>
        <p class="text-sm text-gray-400">Kelola status pemenuhan pesanan dari register kasir</p>
      </div>
      <div class="flex items-center space-x-3">
        <a
          href="/sell"
          class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl text-xs transition shadow flex items-center space-x-1"
        >
          <span>+ Buat Pesanan Baru</span>
        </a>
      </div>
    </div>

    <!-- Filter Bar -->
    <div class="bg-gray-800 border border-gray-700 p-4 rounded-2xl flex flex-wrap items-center justify-between gap-4">
      <!-- Status Filters -->
      <div class="flex items-center flex-wrap gap-1.5">
        <span class="text-xs font-bold text-gray-400 mr-2 uppercase tracking-wider">Status:</span>
        {#each ['all', 'created', 'tendering', 'paid', 'fulfilling', 'fulfilled', 'voided'] as st}
          <button
            onclick={() => statusFilter = st}
            class="px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition {statusFilter === st ? 'bg-emerald-600 text-white shadow' : 'bg-gray-900 text-gray-400 hover:text-white border border-gray-700'}"
          >
            {st}
          </button>
        {/each}
      </div>

      <!-- Vertical Filters -->
      <div class="flex items-center space-x-1.5">
        <span class="text-xs font-bold text-gray-400 mr-2 uppercase tracking-wider">Vertikal:</span>
        {#each ['all', 'grocery', 'food', 'carwash'] as vt}
          <button
            onclick={() => verticalFilter = vt}
            class="px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition {verticalFilter === vt ? 'bg-indigo-600 text-white shadow' : 'bg-gray-900 text-gray-400 hover:text-white border border-gray-700'}"
          >
            {vt}
          </button>
        {/each}
      </div>
    </div>

    <!-- Orders Grid / List -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
      {#each filteredOrders as order (order.id)}
        <div class="bg-gray-800 border border-gray-700 rounded-2xl p-5 flex flex-col justify-between shadow hover:border-gray-600 transition">
          <div>
            <!-- Order Header -->
            <div class="flex items-start justify-between pb-3 border-b border-gray-700">
              <div>
                <span class="font-mono text-xs font-bold text-gray-300">
                  #{order.id.substring(0, 8)}
                </span>
                <p class="text-[11px] text-gray-400">{formatDate(order.created_at)}</p>
              </div>
              <div class="flex items-center space-x-1.5">
                <span class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded {order.vertical === 'grocery' ? 'bg-amber-950 text-amber-300 border border-amber-800' : order.vertical === 'food' ? 'bg-indigo-950 text-indigo-300 border border-indigo-800' : 'bg-cyan-950 text-cyan-300 border border-cyan-800'}">
                  {order.vertical}
                </span>
                <span class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded {order.status === 'fulfilled' || order.status === 'paid' ? 'bg-emerald-950 text-emerald-300 border border-emerald-800' : order.status === 'fulfilling' ? 'bg-blue-950 text-blue-300 border border-blue-800' : order.status === 'voided' ? 'bg-red-950 text-red-300 border border-red-800' : 'bg-amber-950 text-amber-300 border border-amber-800'}">
                  {order.status}
                </span>
              </div>
            </div>

            <!-- Carwash Bay Queue info -->
            {#if order.metadata && order.metadata.bay_queue}
              <div class="mt-3 bg-cyan-950/70 border border-cyan-800 rounded-xl p-2.5 flex items-center justify-between text-xs text-cyan-300">
                <span class="font-bold">Antrean Pencucian:</span>
                <span class="font-mono font-black text-cyan-200">{order.metadata.bay_queue}</span>
              </div>
            {/if}

            <!-- Order Lines List -->
            <div class="mt-3 space-y-1.5">
              {#each order.order_lines || [] as line}
                <div class="flex justify-between items-center text-xs py-1">
                  <span class="text-gray-300 font-medium">
                    {line.qty} {line.unit} × {line.name}
                  </span>
                  <span class="font-mono text-gray-400">
                    {formatMoney(line.total_cents)}
                  </span>
                </div>
              {/each}
            </div>
          </div>

          <!-- Order Footer & Action Buttons -->
          <div class="mt-5 pt-4 border-t border-gray-700 space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-xs text-gray-400">Total Transaksi</span>
              <span class="text-base font-black text-emerald-400 font-mono">
                {formatMoney(order.total_cents)}
              </span>
            </div>

            <div class="flex items-center space-x-2 pt-1">
              {#if ['created', 'paid'].includes(order.status)}
                <button
                  onclick={() => handleFulfill(order.id)}
                  disabled={isProcessing}
                  class="flex-1 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-bold text-xs rounded-xl transition"
                >
                  Mulai Fulfill
                </button>
              {/if}

              {#if order.status === 'fulfilling'}
                <button
                  onclick={() => handleComplete(order.id)}
                  disabled={isProcessing}
                  class="flex-1 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold text-xs rounded-xl transition"
                >
                  Tandai Selesai
                </button>
              {/if}

              {#if ['created', 'tendering'].includes(order.status)}
                <button
                  onclick={() => openVoidModal(order)}
                  disabled={isProcessing}
                  class="py-2 px-3 bg-red-950 hover:bg-red-900 border border-red-800 text-red-300 font-bold text-xs rounded-xl transition"
                >
                  Void
                </button>
              {/if}
            </div>
          </div>
        </div>
      {:else}
        <div class="col-span-full py-16 text-center text-gray-500 bg-gray-800/40 rounded-2xl border border-gray-800">
          <span class="text-4xl block mb-2 opacity-50">📂</span>
          <p class="font-bold text-sm">Tidak Ada Order Sesuai Filter</p>
          <p class="text-xs text-gray-600 mt-1">Coba ubah filter status atau vertikal di atas.</p>
        </div>
      {/each}
    </div>
  </main>

  <!-- Void Confirmation Modal -->
  {#if isVoidModalOpen && orderToVoid}
    <div class="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-gray-800 border border-gray-700 rounded-2xl w-full max-w-md overflow-hidden shadow-2xl p-6 space-y-4">
        <h3 class="text-lg font-bold text-red-400">Batalkan Pesanan (Void)</h3>
        <p class="text-xs text-gray-300">
          Order ID: <span class="font-mono font-bold">#{orderToVoid.id}</span>
        </p>
        <p class="text-xs text-gray-400">
          Aksi void akan dicatat ke dalam audit trail sistem forensik. Masukkan alasan pembatalan:
        </p>
        <textarea
          bind:value={voidReason}
          rows="3"
          class="w-full bg-gray-900 border border-gray-700 rounded-xl p-3 text-sm text-gray-200 focus:outline-none focus:border-red-500"
          placeholder="Alasan void..."
        ></textarea>
        <div class="flex justify-end space-x-3 pt-2">
          <button
            onclick={() => isVoidModalOpen = false}
            class="px-4 py-2 text-xs font-bold text-gray-400 hover:text-white rounded-lg hover:bg-gray-700 transition"
          >
            Batal
          </button>
          <button
            onclick={submitVoid}
            disabled={isProcessing || !voidReason.trim()}
            class="px-5 py-2 bg-red-600 hover:bg-red-500 disabled:opacity-50 text-white font-bold rounded-xl text-xs transition"
          >
            Konfirmasi Void
          </button>
        </div>
      </div>
    </div>
  {/if}
</div>
