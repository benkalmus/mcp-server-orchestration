// Stealth init script for Playwright MCP
// Evaluated before any page scripts to hide automation indicators.

(() => {
  // 1. Remove navigator.webdriver flag
  Object.defineProperty(navigator, 'webdriver', {
    get: () => false,
    configurable: true,
  });

  // 2. Override navigator.platform
  Object.defineProperty(navigator, 'platform', {
    get: () => 'MacIntel',
    configurable: true,
  });

  // 3. Override navigator.languages
  Object.defineProperty(navigator, 'languages', {
    get: () => ['en-GB', 'en-US', 'en'],
    configurable: true,
  });

  // 4. Patch WebGL vendor/renderer to look like a real Mac GPU
  const getParameter = WebGLRenderingContext.prototype.getParameter;
  WebGLRenderingContext.prototype.getParameter = function (param) {
    // UNMASKED_VENDOR_WEBGL
    if (param === 37445) return 'Intel Inc.';
    // UNMASKED_RENDERER_WEBGL
    if (param === 37446) return 'Intel Iris OpenGL Engine';
    return getParameter.call(this, param);
  };

  const getParameter2 = WebGL2RenderingContext.prototype.getParameter;
  WebGL2RenderingContext.prototype.getParameter = function (param) {
    if (param === 37445) return 'Intel Inc.';
    if (param === 37446) return 'Intel Iris OpenGL Engine';
    return getParameter2.call(this, param);
  };

  // 5. Prevent chrome.runtime detection (used by some bot detectors)
  if (!window.chrome) {
    window.chrome = {};
  }
  if (!window.chrome.runtime) {
    window.chrome.runtime = {};
  }

  // 6. Override permissions query to look normal
  const originalQuery = window.Permissions?.prototype?.query;
  if (originalQuery) {
    window.Permissions.prototype.query = function (parameters) {
      if (parameters.name === 'notifications') {
        return Promise.resolve({ state: Notification.permission });
      }
      return originalQuery.call(this, parameters);
    };
  }

  // 7. Patch connection.rtt (bot detectors check for 0 rtt in headless)
  if (navigator.connection) {
    Object.defineProperty(navigator.connection, 'rtt', {
      get: () => 50,
      configurable: true,
    });
  }

  // 8. Hide HeadlessChrome from user agent string
  const uaDesc = Object.getOwnPropertyDescriptor(navigator, 'userAgent');
  if (uaDesc && uaDesc.get) {
    Object.defineProperty(navigator, 'userAgent', {
      get: () => uaDesc.get.call(navigator).replace('HeadlessChrome', 'Chrome'),
      configurable: true,
    });
  }
})();
