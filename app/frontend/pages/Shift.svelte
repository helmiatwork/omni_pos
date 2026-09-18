<script>
  import { router } from '@inertiajs/svelte'
  import Navbar from '../components/Navbar.svelte'
  import { formatMoney, formatDate } from '../lib/utils'

  let { current_shift = null, past_shifts = [], audit_logs = [] } = $props()

  // Svelte 5 Runes
  let openingCash = $state(200_000)
  let countedCash = $state(0)
  let isProcessing = $state(false)
  let notification = $state(null)
  let closeResult = $state(null)

  function showNotification(text, type = 'success') {
    notification = { text, type }
    setTimeout(() => {
      notification = null
    }, 5000)
  }

  async function handleOpenShift() {
    isProcessing = true
    try {
      const res = await fetch('/shifts/open', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          opening_cash: openingCash,
          device_id: 'Station-01'
        })
      })

      const data = await res.json()
      if (res.ok && data.success) {
        showNotification('Shift kasir berhasil dibuka!', 'success')
        router.reload()
      } else {
        showNotification(data.errors ? data.errors.join(', ') : (data.error || 'Gagal membuka shift'), 'error')
      }
    } catch (e) {
      showNotification('Kesalahan jaringan saat membuka shift', 'error')
    } finally {
      isProcessing = false
    }
  }

  async function handleCloseShift() {
    if (!current_shift) return
    isProcessing = true
    try {
      const res = await fetch(`/shifts/${current_shift.id}/close`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          counted_cash: countedCash
        })
      })

      const data = await res.json()
      if (res.ok && data.success) {
        closeResult = data
        showNotification(`Shift berhasil ditutup! Selisih kas: ${formatMoney(data.variance)}`, 'success')
        setTimeout(() => {
          router.reload()
        }, 3000)
      } else {
        showNotification(data.error || 'Gagal menutup shift', 'error')
      }
    } catch (e) {
      showNotification('Kesalahan jaringan saat menutup shift', 'error')
    } finally {
      isProcessing = false
    }
  }
</script>

<div class="min-h-screen bg-gray-900 text-gray-100 flex flex-col font-sans">
  <Navbar active="shifts" {current_shift} />

  <!-- Flash Notification -->
  {#if notification}
    <div class="fixed top-16 right-6 z-50 px-4 py-3 rounded-lg shadow-xl text-sm font-medium border flex items-center space-x-2 transition-all {notification.type === 'error' ? 'bg-red-950 border-red-700 text-red-200' : 'bg-emerald-950 border-emerald-700 text-emerald-200'}">
      <span>{notification.type === 'error' ? '⚠️' : '✓'}</span>
      <span>{notification.text}</span>
    </div>
  {/if}

  <main class="flex-1 p-6 max-w-7xl w-full mx-auto space-y-8">
    <div>
      <h1 class="text-2xl font-black text-white">Manajemen Shift & Cash Drawer</h1>
      <p class="text-sm text-gray-400">Pencatatan modal kasir, penutupan blind-close, dan audit trail pergerakan uang fisik</p>
    </div>

    <!-- Active Shift Panel or Open Shift Panel -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-lg">
        {#if current_shift}
          <!-- Current Active Shift -->
          <div class="space-y-6">
            <div class="flex items-center justify-between pb-4 border-b border-gray-700">
              <div class="flex items-center space-x-3">
                <span class="w-3.5 h-3.5 rounded-full bg-emerald-400 animate-pulse"></span>
                <div>
                  <h2 class="text-lg font-bold text-white">Shift Kasir Sedang Aktif</h2>
                  <p class="text-xs text-gray-400">Device ID: <span class="font-mono text-gray-300">{current_shift.device_id}</span></p>
                </div>
              </div>
              <span class="px-3 py-1 bg-emerald-950 border border-emerald-700 text-emerald-300 text-xs font-bold uppercase rounded-full">
                Status: Buka
              </span>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-center">
              <div class="bg-gray-900 p-4 rounded-xl border border-gray-700">
                <span class="text-xs text-gray-400 font-medium">Kasir Bertugas</span>
                <p class="text-base font-bold text-gray-200 mt-1">{current_shift.cashier ? current_shift.cashier.name : 'Kasir Utama'}</p>
              </div>
              <div class="bg-gray-900 p-4 rounded-xl border border-gray-700">
                <span class="text-xs text-gray-400 font-medium">Modal Awal (Float)</span>
                <p class="text-base font-bold text-emerald-400 mt-1 font-mono">{formatMoney(current_shift.opening_cash)}</p>
              </div>
              <div class="bg-gray-900 p-4 rounded-xl border border-gray-700">
                <span class="text-xs text-gray-400 font-medium">Waktu Buka</span>
                <p class="text-xs font-bold text-gray-300 mt-2 font-mono">{formatDate(current_shift.opened_at)}</p>
              </div>
            </div>

            <!-- Blind Close Section -->
            <div class="bg-gray-900/80 border border-gray-700 p-5 rounded-xl space-y-4">
              <div>
                <h3 class="text-base font-bold text-amber-300">Form Blind Close (Tutup Shift Kasir)</h3>
                <p class="text-xs text-gray-400 mt-1">
                  Hitung seluruh uang fisik di laci kasir dan masukkan nominal di bawah. Sistem akan secara otomatis menghitung selisih (variance) berdasarkan transaksi kas yang tercatat tanpa memperlihatkan expected cash sebelum input kasir.
                </p>
              </div>

              <div>
                <label for="countedCashInput" class="block text-xs font-bold uppercase tracking-wider text-gray-300 mb-1">
                  Uang Fisik Dihitung Kasir (Counted Cash):
                </label>
                <div class="relative">
                  <span class="absolute left-4 top-3 text-sm font-bold text-gray-500 font-mono">Rp</span>
                  <input
                    id="countedCashInput"
                    type="number"
                    bind:value={countedCash}
                    placeholder="0"
                    class="w-full bg-gray-800 border border-gray-700 rounded-xl pl-12 pr-4 py-2.5 text-lg font-bold font-mono text-white focus:outline-none focus:border-amber-500"
                  />
                </div>
              </div>

              {#if closeResult}
                <div class="p-4 bg-gray-800 border border-gray-700 rounded-xl space-y-2">
                  <div class="flex justify-between text-xs">
                    <span class="text-gray-400">Uang Dihitung:</span>
                    <span class="font-mono font-bold text-gray-200">{formatMoney(closeResult.shift.counted_cash)}</span>
                  </div>
                  <div class="flex justify-between text-xs">
                    <span class="text-gray-400">Ekspektasi Sistem:</span>
                    <span class="font-mono font-bold text-gray-200">{formatMoney(closeResult.shift.expected_cash)}</span>
                  </div>
                  <div class="flex justify-between text-sm pt-2 border-t border-gray-700 font-bold">
                    <span>Selisih (Variance):</span>
                    <span class="font-mono {closeResult.variance >= 0 ? 'text-emerald-400' : 'text-red-400'}">
                      {formatMoney(closeResult.variance)}
                    </span>
                  </div>
                </div>
              {/if}

              <button
                onclick={handleCloseShift}
                disabled={isProcessing}
                class="w-full py-3 bg-amber-600 hover:bg-amber-500 disabled:opacity-50 text-white font-bold rounded-xl text-sm transition shadow-lg flex items-center justify-center space-x-2"
              >
                <span>{isProcessing ? 'Menghitung Selisih Kas...' : '🔒 Tutup Shift Kasir (Blind Close)'}</span>
              </button>
            </div>
          </div>
        {:else}
          <!-- No Active Shift: Open Shift Form -->
          <div class="space-y-6">
            <div class="pb-4 border-b border-gray-700">
              <h2 class="text-lg font-bold text-white">Buka Shift Kasir Baru</h2>
              <p class="text-xs text-gray-400">Tidak ada shift yang sedang aktif pada terminal register ini.</p>
            </div>

            <div class="space-y-4">
              <div>
                <label for="openingCashInput" class="block text-xs font-bold uppercase tracking-wider text-gray-300 mb-1">
                  Modal Awal Kasir (Opening Float):
                </label>
                <div class="relative">
                  <span class="absolute left-4 top-3 text-sm font-bold text-gray-500 font-mono">Rp</span>
                  <input
                    id="openingCashInput"
                    type="number"
                    bind:value={openingCash}
                    class="w-full bg-gray-900 border border-gray-700 rounded-xl pl-12 pr-4 py-2.5 text-lg font-bold font-mono text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <!-- Quick Float Preset Chips -->
              <div class="flex space-x-2">
                <button
                  onclick={() => openingCash = 100_000}
                  class="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 rounded-lg text-xs font-medium text-gray-300"
                >
                  100.000
                </button>
                <button
                  onclick={() => openingCash = 200_000}
                  class="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 rounded-lg text-xs font-medium text-gray-300"
                >
                  200.000
                </button>
                <button
                  onclick={() => openingCash = 500_000}
                  class="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 rounded-lg text-xs font-medium text-gray-300"
                >
                  500.000
                </button>
              </div>

              <button
                onclick={handleOpenShift}
                disabled={isProcessing}
                class="w-full py-3 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-bold rounded-xl text-sm transition shadow-lg flex items-center justify-center space-x-2"
              >
                <span>{isProcessing ? 'Membuka...' : '🔓 Buka Shift Sekarang'}</span>
              </button>
            </div>
          </div>
        {/if}
      </div>

      <!-- Station Info Sidebar -->
      <div class="bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-lg space-y-4">
        <h3 class="text-base font-bold text-white">Informasi Terminal Register</h3>
        <div class="space-y-3 text-xs">
          <div class="flex justify-between py-1 border-b border-gray-700">
            <span class="text-gray-400">Terminal Station</span>
            <span class="font-mono font-bold text-gray-200">Station-01</span>
          </div>
          <div class="flex justify-between py-1 border-b border-gray-700">
            <span class="text-gray-400">Printer Nota</span>
            <span class="text-emerald-400 font-medium">ESC/POS (Ready)</span>
          </div>
          <div class="flex justify-between py-1 border-b border-gray-700">
            <span class="text-gray-400">Timbangan Digital</span>
            <span class="text-amber-400 font-medium">Web Serial (Calibrated)</span>
          </div>
          <div class="flex justify-between py-1 border-b border-gray-700">
            <span class="text-gray-400">Offline Resilience</span>
            <span class="text-indigo-400 font-medium">IndexedDB Outbox Active</span>
          </div>
        </div>

        <div class="pt-4">
          <a
            href="/pad"
            target="_blank"
            rel="noreferrer"
            class="w-full py-2.5 bg-gray-700 hover:bg-gray-600 text-gray-200 font-bold rounded-xl text-xs flex items-center justify-center space-x-2 transition"
          >
            <span>Buka Layar Pelanggan (Customer Pad)</span>
            <span>↗</span>
          </a>
        </div>
      </div>
    </div>

    <!-- Past Shifts History -->
    <div class="bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-lg space-y-4">
      <h3 class="text-lg font-bold text-white">Riwayat Shift Kasir Selesai</h3>
      <div class="overflow-x-auto">
        <table class="w-full text-left text-xs">
          <thead class="bg-gray-900/60 text-gray-400 uppercase tracking-wider border-b border-gray-700">
            <tr>
              <th class="p-3">Kasir</th>
              <th class="p-3">Waktu Buka</th>
              <th class="p-3">Waktu Tutup</th>
              <th class="p-3 text-right">Modal Awal</th>
              <th class="p-3 text-right">Fisik Dihitung</th>
              <th class="p-3 text-right">Ekspektasi Sistem</th>
              <th class="p-3 text-right">Selisih (Variance)</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-700/60">
            {#each past_shifts as ps (ps.id)}
              <tr class="hover:bg-gray-750 transition">
                <td class="p-3 font-bold text-gray-200">{ps.cashier ? ps.cashier.name : 'Kasir'}</td>
                <td class="p-3 font-mono text-gray-400">{formatDate(ps.opened_at)}</td>
                <td class="p-3 font-mono text-gray-400">{formatDate(ps.closed_at)}</td>
                <td class="p-3 text-right font-mono">{formatMoney(ps.opening_cash)}</td>
                <td class="p-3 text-right font-mono">{formatMoney(ps.counted_cash)}</td>
                <td class="p-3 text-right font-mono">{formatMoney(ps.expected_cash)}</td>
                <td class="p-3 text-right font-mono font-bold {ps.variance >= 0 ? 'text-emerald-400' : 'text-red-400'}">
                  {formatMoney(ps.variance)}
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="7" class="p-6 text-center text-gray-500 italic">
                  Belum ada riwayat shift yang ditutup.
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>

    <!-- Forensics Audit Log -->
    <div class="bg-gray-800 border border-gray-700 rounded-2xl p-6 shadow-lg space-y-4">
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-lg font-bold text-white">Log Audit POS (Forensik)</h3>
          <p class="text-xs text-gray-400">Catatan tidak dapat diubah (append-only) untuk aksi void, refund, dan shift close</p>
        </div>
        <span class="text-[10px] uppercase font-bold text-gray-500 font-mono">Anti-tamper DB</span>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full text-left text-xs">
          <thead class="bg-gray-900/60 text-gray-400 uppercase tracking-wider border-b border-gray-700">
            <tr>
              <th class="p-3">Waktu</th>
              <th class="p-3">Event</th>
              <th class="p-3">Actor ID</th>
              <th class="p-3">Payload Data</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-700/60 font-mono">
            {#each audit_logs as log (log.id)}
              <tr class="hover:bg-gray-750 transition">
                <td class="p-3 text-gray-400">{formatDate(log.created_at)}</td>
                <td class="p-3">
                  <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase {log.event_name === 'void' ? 'bg-red-950 text-red-400 border border-red-800' : 'bg-blue-950 text-blue-400 border border-blue-800'}">
                    {log.event_name}
                  </span>
                </td>
                <td class="p-3 text-gray-400">#{log.actor_id.substring(0, 8)}</td>
                <td class="p-3 text-gray-300 max-w-xs truncate">
                  {JSON.stringify(log.payload)}
                </td>
              </tr>
            {:else}
              <tr>
                <td colspan="4" class="p-6 text-center text-gray-500 italic">
                  Belum ada log audit yang tercatat.
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  </main>
</div>
