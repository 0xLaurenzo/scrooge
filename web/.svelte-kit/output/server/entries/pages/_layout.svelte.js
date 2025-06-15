import "clsx";
import { c as pop, p as push } from "../../chunks/index.js";
import { createAppKit } from "@reown/appkit";
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi";
import { reconnect } from "@wagmi/core";
import { mainnet, sepolia, goerli, arbitrum, arbitrumSepolia, optimism, optimismSepolia, polygon, polygonAmoy, base, baseSepolia } from "viem/chains";
const projectId = "";
const wagmiAdapter = new WagmiAdapter({
  projectId,
  networks: [
    mainnet,
    sepolia,
    goerli,
    arbitrum,
    arbitrumSepolia,
    optimism,
    optimismSepolia,
    polygon,
    polygonAmoy,
    base,
    baseSepolia
  ]
});
createAppKit({
  adapters: [wagmiAdapter],
  projectId,
  networks: [
    mainnet,
    sepolia,
    goerli,
    arbitrum,
    arbitrumSepolia,
    optimism,
    optimismSepolia,
    polygon,
    polygonAmoy,
    base,
    baseSepolia
  ],
  metadata: {
    name: "Svelte EVM Template",
    description: "Svelte EVM Template with AppKit",
    url: "https://example.com",
    icons: ["/logo.png"]
  },
  features: {
    analytics: true,
    email: false,
    socials: false
  }
});
if (typeof window !== "undefined") {
  reconnect(wagmiAdapter.wagmiConfig);
}
function WalletButton($$payload, $$props) {
  push();
  $$payload.out += `<appkit-button></appkit-button>`;
  pop();
}
function Navbar($$payload) {
  $$payload.out += `<nav class="fixed left-0 right-0 top-0 flex items-center justify-between border-b border-gray-300 p-1 backdrop-blur-sm"><a href="/" class="rounded px-3 py-1 text-lg font-bold italic hover:bg-gray-100"><img src="/logo.png" alt="Logo" class="inline-block mr-2" style="width: 42px; height: 24px;"/> Your Thing here</a> <div class="space-x-4"><a href="/placeholder1" class="text-black hover:text-gray-600">Placeholder 1</a> <a href="/placeholder2" class="text-black hover:text-gray-600">Placeholder 2</a> <a href="/placeholder3" class="text-black hover:text-gray-600">Placeholder 3</a></div> <div>`;
  WalletButton($$payload);
  $$payload.out += `<!----></div></nav>`;
}
function _layout($$payload, $$props) {
  let { children } = $$props;
  Navbar($$payload);
  $$payload.out += `<!---->; <main class="pt-14">`;
  children($$payload);
  $$payload.out += `<!----></main>`;
}
export {
  _layout as default
};
