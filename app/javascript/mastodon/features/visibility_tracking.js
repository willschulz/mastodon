import { connectUserStream } from 'mastodon/actions/streaming';


const SEEN_ENDPOINT = '/api/v1/statuses/seen';

function isElementVisible(el) {
  const rect = el.getBoundingClientRect();
  return (
    rect.top < window.innerHeight &&
    rect.bottom > 0 &&
    rect.left < window.innerWidth &&
    rect.right > 0
  );
}

const seenIds = new Set();

export function initializeVisibilityTracking() {
  setInterval(() => {
    if (!window.location.pathname.endsWith('/home')) return;

    const articles = document.querySelectorAll('article');
    const newIds = [];

    articles.forEach(article => {
      if (isElementVisible(article)) {
        const dataId = article.getAttribute('data-id');
        if (dataId && !seenIds.has(dataId)) {
          newIds.push(dataId);
          seenIds.add(dataId);
        }
      }
    });

    if (newIds.length > 0) {
      fetch(SEEN_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids: newIds })
      }).catch(err => {
        console.error('Failed to send /seen POST:', err);
      });
    }
  }, 500);
} 