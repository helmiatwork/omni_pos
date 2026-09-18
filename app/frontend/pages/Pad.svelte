<script>
  import { onMount } from 'svelte'
  import { formatMoney } from '../lib/utils'

  let { order = null, station_ref = 'Station-01' } = $props()

  // Svelte 5 Rune
  let activeOrder = $state(null)

  $effect(() => {
    activeOrder = order
  })

  // Periodic polling for customer pad so customer sees real-time updates as cashier scans/types
  onMount(() => {
    const interval = setInterval(async () => {
      try {
        const res = await fetch(`/pad?station_ref=${station_ref}`, {
          headers: { 'Accept': 'application/json' }
        })
        if (res.ok) {
          const data = await res.json()
          activeOrder = data.order
        }
      } catch (e) {
        // silent background polling
      }
    }, 2000)

    return () => clearInterval(interval)
  })

  let remainingDueCents = $derived.by(() => {
    if (!activeOrder) return 0
    const captured = (activeOrder.tenders || [])
      .filter(t => t.status === 'captured')
      .reduce((s, t) => s + Number(t.amount_cents), 0)
    return Math.max(0, activeOrder.total_cents - captured)
  })
</script>

<div class="min-h-screen bg-gray-950 text-white flex flex-col justify-between font-sans select-none">
  <!-- Top Bar -->
  <header class="bg-gray-900 border-b border-gray-800 px-8 py-5 flex items-center justify-between shadow-md">
    <div class="flex items-center space-x-3">
      <span class="w-10 h-10 rounded-xl bg-emerald-600 flex items-center justify-center font-black text-xl text-white shadow-lg">
        ⚡
      </span>
      <div>
        <span class="font-extrabold text-xl tracking-tight">Omni<span class="text-emerald-400">POS</span></span>
        <span class="text-xs text-gray-400 block">Customer Display Terminal</span>
      </div>
    </div>
    <div class="flex items-center space-x-3">
      <div class="flex items-center space-x-2 bg-gray-800 px-3 py-1.5 rounded-full border border-gray-700">
        <span class="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></span>
        <span class="text-xs font-mono font-bold text-gray-200">{station_ref}</span>
      </div>
    </div>
  </header>

  <!-- Main Content Area -->
  <main class="flex-1 flex items-center justify-center p-8 max-w-7xl w-full mx-auto">
    {#if activeOrder}
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 w-full">
        <!-- Left: Line items breakdown (7 cols) -->
        <div class="lg:col-span-7 bg-gray-900 border border-gray-800 rounded-3xl p-8 shadow-2xl flex flex-col justify-between">
          <div>
            <div class="flex items-center justify-between pb-4 border-b border-gray-800">
              <h2 class="text-lg font-bold text-gray-200">Daftar Belanja Anda</h2>
              <span class="text-xs font-mono text-gray-500">#{activeOrder.id.substring(0, 8)}</span>
            </div>

            <!-- Items list -->
            <div class="mt-6 space-y-4 max-h-[480px] overflow-y-auto pr-2">
              {#each activeOrder.order_lines || [] as line}
                <div class="flex items-start justify-between py-3 border-b border-gray-800/60">
                  <div>
                    <h3 class="text-base font-bold text-gray-100">{line.name}</h3>
                    <p class="text-xs text-gray-400 font-mono mt-0.5">
                      {line.qty} {line.unit} × {formatMoney(line.unit_price_cents)}
                    </p>
                    {#if line.modifiers && Object.keys(line.modifiers).length > 0}
                      <div class="flex flex-wrap gap-1 mt-1">
                        {#each Object.entries(line.modifiers) as [k, v]}
                          <span class="text-[10px] bg-gray-800 text-gray-300 px-1.5 py-0.5 rounded">
                            {k}: {v}
                          </span>
                        {/each}
                      </div>
                    {/if}
                  </div>
                  <span class="text-base font-bold font-mono text-gray-200">
                    {formatMoney(line.total_cents)}
                  </span>
                </div>
              {/each}
            </div>
          </div>

          <!-- Total Summary -->
          <div class="mt-8 pt-6 border-t border-gray-800 space-y-3">
            <div class="flex justify-between items-center text-sm text-gray-400">
              <span>Subtotal Pembelian</span>
              <span class="font-mono text-gray-200">{formatMoney(activeOrder.total_cents)}</span>
            </div>
            <div class="flex justify-between items-center pt-2 border-t border-gray-800">
              <span class="text-xl font-bold text-gray-200">Total Tagihan</span>
              <span class="text-3xl font-black text-emerald-400 font-mono">
                {formatMoney(activeOrder.total_cents)}
              </span>
            </div>
          </div>
        </div>

        <!-- Right: Payment & QR Prompt (5 cols) -->
        <div class="lg:col-span-5 flex flex-col justify-center">
          {#if activeOrder.status === 'paid' || activeOrder.status === 'fulfilled'}
            <div class="bg-gray-900 border border-emerald-600/40 rounded-3xl p-8 text-center shadow-2xl space-y-6">
              <div class="w-20 h-20 bg-emerald-950 border border-emerald-500 rounded-full flex items-center justify-center mx-auto text-4xl shadow-inner">
                ✓
              </div>
              <div>
                <h3 class="text-2xl font-black text-emerald-400">Pembayaran Berhasil!</h3>
                <p class="text-sm text-gray-400 mt-2">Terima kasih atas kunjungan Anda.</p>
              </div>
              <div class="p-4 bg-gray-850 rounded-2xl border border-gray-800 text-xs font-mono text-gray-400">
                Lunas via Multi-Tender Engine
              </div>
            </div>
          {:else}
            <!-- QR / Payment Prompt -->
            <div class="bg-gray-900 border border-gray-800 rounded-3xl p-8 text-center shadow-2xl space-y-6">
              <div>
                <span class="text-xs uppercase tracking-widest font-bold text-emerald-400 bg-emerald-950 px-3 py-1 rounded-full border border-emerald-800">
                  Metode Pembayaran Digital
                </span>
                <h3 class="text-xl font-extrabold text-white mt-3">Scan untuk Membayar</h3>
                <p class="text-xs text-gray-400 mt-1">Gunakan aplikasi omniWallet atau e-wallet QRIS Anda</p>
              </div>

              <!-- Simulated QR Code -->
              <div class="p-6 bg-white rounded-2xl mx-auto w-60 h-60 flex flex-col items-center justify-center shadow-xl">
                <!-- SVG simulated QR pattern -->
                <svg class="w-48 h-48 text-gray-900" viewBox="0 0 100 100" fill="currentColor">
                  <!-- Corner 1 -->
                  <rect x="10" y="10" width="25" height="25" fill="none" stroke="currentColor" stroke-width="4"/>
                  <rect x="16" y="16" width="13" height="13"/>
                  <!-- Corner 2 -->
                  <rect x="65" y="10" width="25" height="25" fill="none" stroke="currentColor" stroke-width="4"/>
                  <rect x="71" y="16" width="13" height="13"/>
                  <!-- Corner 3 -->
                  <rect x="10" y="65" width="25" height="25" fill="none" stroke="currentColor" stroke-width="4"/>
                  <rect x="16" y="71" width="13" height="13"/>
                  <!-- Random-like QR pixels -->
                  <rect x="42" y="12" width="6" height="6"/>
                  <rect x="52" y="12" width="6" height="6"/>
                  <rect x="42" y="24" width="6" height="6"/>
                  <rect x="12" y="44" width="6" height="6"/>
                  <rect x="24" y="44" width="6" height="6"/>
                  <rect x="36" y="44" width="6" height="6"/>
                  <rect x="48" y="44" width="8" height="8"/>
                  <rect x="64" y="44" width="6" height="6"/>
                  <rect x="76" y="44" width="6" height="6"/>
                  <rect x="42" y="60" width="6" height="6"/>
                  <rect x="54" y="60" width="6" height="6"/>
                  <rect x="42" y="76" width="6" height="6"/>
                  <rect x="54" y="76" width="6" height="6"/>
                  <rect x="70" y="70" width="14" height="14"/>
                </svg>
                <span class="text-[10px] font-mono font-bold text-gray-700 tracking-wider mt-1">omniWallet · QRIS</span>
              </div>

              <!-- Remaining Due -->
              <div class="bg-gray-850 border border-gray-800 rounded-2xl p-4">
                <span class="text-xs text-gray-400">Sisa yang harus dibayar:</span>
                <p class="text-2xl font-black text-amber-400 font-mono mt-1">
                  {formatMoney(remainingDueCents)}
                </p>
              </div>
            </div>
          {/if}
        </div>
      </div>
    {:else}
      <!-- Idle / Welcome State -->
      <div class="text-center max-w-lg space-y-6">
        <div class="w-24 h-24 rounded-3xl bg-gray-900 border border-gray-800 flex items-center justify-center mx-auto shadow-2xl">
          <span class="text-5xl">🛍️</span>
        </div>
        <div>
          <h2 class="text-3xl font-black text-white">Selamat Datang di OmniPOS</h2>
          <p class="text-sm text-gray-400 mt-2">
            Kasir kami siap melayani pesanan Anda. Detail transaksi akan otomatis tampil di layar ini saat kasir memasukkan item.
          </p>
        </div>
        <div class="inline-flex items-center space-x-2 bg-gray-900 border border-gray-800 px-4 py-2 rounded-full text-xs text-gray-400">
          <span class="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
          <span>Terminal Kiosk Siaga ({station_ref})</span>
        </div>
      </div>
    {/if}
  </main>

  <!-- Bottom Brand Footer -->
  <footer class="bg-gray-900 border-t border-gray-800 px-8 py-4 flex items-center justify-between text-xs text-gray-500">
    <span>Didukung oleh omniWallet Engine & OmniPOS Core</span>
    <span class="font-mono">Inertia.js + Svelte 5</span>
  </footer>
</div>
