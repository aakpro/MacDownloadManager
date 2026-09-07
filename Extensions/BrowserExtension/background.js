// MacDownloader Chrome / Brave / Firefox / Edge Extension Background Service Worker

const NATIVE_HOST_NAME = "com.macdownloader.nativehost";

// Context Menus
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "download-with-macdownloader",
    title: "Download with MacDownloader",
    contexts: ["link", "image", "video", "audio"]
  });

  chrome.contextMenus.create({
    id: "download-page-with-macdownloader",
    title: "Download Page with MacDownloader",
    contexts: ["page"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  const targetURL = info.linkUrl || info.srcUrl || (info.menuItemId === "download-page-with-macdownloader" ? info.pageUrl : null);
  if (!targetURL) return;

  sendToMacDownloader({
    action: "download",
    url: targetURL,
    referer: tab?.url || ""
  });
});

// Automatic Browser Download Interception
chrome.downloads.onCreated.addListener((downloadItem) => {
  if (!downloadItem || !downloadItem.url) return;

  // Ignore data URIs or blob URIs
  if (downloadItem.url.startsWith("data:") || downloadItem.url.startsWith("blob:")) {
    return;
  }

  // Cancel the standard browser download
  chrome.downloads.cancel(downloadItem.id, () => {
    chrome.downloads.erase({ id: downloadItem.id });
  });

  // Forward to MacDownloader
  sendToMacDownloader({
    action: "download",
    url: downloadItem.url,
    filename: downloadItem.filename || null,
    referer: downloadItem.referrer || ""
  });
});

function sendToMacDownloader(payload) {
  try {
    chrome.runtime.sendNativeMessage(NATIVE_HOST_NAME, payload, (response) => {
      if (chrome.runtime.lastError) {
        console.warn("Native host not reachable, falling back to URL scheme:", chrome.runtime.lastError.message);
        // Fallback: Open URL scheme
        const fallbackURL = `macdownloader://download?url=${encodeURIComponent(payload.url)}`;
        chrome.tabs.create({ url: fallbackURL, active: false }, (tab) => {
          setTimeout(() => {
            if (tab && tab.id) chrome.tabs.remove(tab.id);
          }, 1000);
        });
      } else {
        console.log("MacDownloader Native Host response:", response);
      }
    });
  } catch (err) {
    console.error("Error sending to MacDownloader:", err);
  }
}
