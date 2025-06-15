export const manifest = (() => {
function __memo(fn) {
	let value;
	return () => value ??= (value = fn());
}

return {
	appDir: "_app",
	appPath: "_app",
	assets: new Set(["favicon.png","logo.png"]),
	mimeTypes: {".png":"image/png"},
	_: {
		client: {start:"_app/immutable/entry/start.I2qNVnOu.js",app:"_app/immutable/entry/app.B70RZr0D.js",imports:["_app/immutable/entry/start.I2qNVnOu.js","_app/immutable/chunks/CnUtcAi5.js","_app/immutable/chunks/B_qOtKNu.js","_app/immutable/chunks/Bb8jmPeH.js","_app/immutable/entry/app.B70RZr0D.js","_app/immutable/chunks/Dp1pzeXC.js","_app/immutable/chunks/B_qOtKNu.js","_app/immutable/chunks/DfvUvj9G.js","_app/immutable/chunks/BTtfwK2B.js","_app/immutable/chunks/Bb8jmPeH.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./nodes/0.js')),
			__memo(() => import('./nodes/1.js')),
			__memo(() => import('./nodes/2.js'))
		],
		routes: [
			{
				id: "/",
				pattern: /^\/$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 2 },
				endpoint: null
			}
		],
		prerendered_routes: new Set([]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();
