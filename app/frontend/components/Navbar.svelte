<script>
  let { active = 'sell', current_shift = null } = $props();
</script>

<header class="bg-gray-800 border-b border-gray-700 px-6 py-3 flex items-center justify-between text-white select-none">
  <div class="flex items-center space-x-6">
    <a href="/sell" class="flex items-center space-x-2.5">
      <span class="w-8 h-8 rounded-lg bg-emerald-600 flex items-center justify-center font-black text-lg text-white shadow">
        ⚡
      </span>
      <span class="font-bold text-lg tracking-tight">Omni<span class="text-emerald-400">POS</span></span>
    </a>

    <nav class="flex items-center space-x-1">
      <a
        href="/sell"
        class="px-3.5 py-1.5 rounded-md text-sm font-medium transition {active === 'sell' ? 'bg-emerald-600 text-white' : 'text-gray-300 hover:bg-gray-700 hover:text-white'}"
      >
        Kasir (Sell)
      </a>
      <a
        href="/orders"
        class="px-3.5 py-1.5 rounded-md text-sm font-medium transition {active === 'orders' ? 'bg-emerald-600 text-white' : 'text-gray-300 hover:bg-gray-700 hover:text-white'}"
      >
        Daftar Pesanan
      </a>
      <a
        href="/shifts"
        class="px-3.5 py-1.5 rounded-md text-sm font-medium transition {active === 'shifts' ? 'bg-emerald-600 text-white' : 'text-gray-300 hover:bg-gray-700 hover:text-white'}"
      >
        Shift & Kas
      </a>
      <a
        href="/pad"
        target="_blank"
        rel="noreferrer"
        class="px-3.5 py-1.5 rounded-md text-sm font-medium text-gray-400 hover:bg-gray-700 hover:text-white transition flex items-center space-x-1"
      >
        <span>Customer Pad</span>
        <span class="text-xs opacity-70">↗</span>
      </a>
    </nav>
  </div>

  <div class="flex items-center space-x-4 text-xs">
    {#if current_shift}
      <div class="flex items-center space-x-2 bg-emerald-950 border border-emerald-700 text-emerald-300 px-3 py-1.5 rounded-full">
        <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
        <span class="font-semibold">Shift Aktif</span>
        <span class="opacity-70">({current_shift.cashier ? current_shift.cashier.name : 'Kasir'})</span>
      </div>
    {:else}
      <a
        href="/shifts"
        class="flex items-center space-x-2 bg-amber-950 border border-amber-700 text-amber-300 px-3 py-1.5 rounded-full hover:bg-amber-900 transition"
      >
        <span class="w-2 h-2 rounded-full bg-amber-400"></span>
        <span class="font-semibold">Shift Belum Buka</span>
        <span class="underline ml-1">Buka Sekarang</span>
      </a>
    {/if}
    <div class="text-gray-400 border-l border-gray-700 pl-4 font-mono">
      Station-01
    </div>
  </div>
</header>
