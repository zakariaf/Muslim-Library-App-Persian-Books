// ==========================================
// Islamic Library - Main JavaScript
// ==========================================

const CATALOG_URL = '../index.json';
const BASE_URL = '..';

// ==========================================
// Fetch Catalog
// ==========================================

async function fetchCatalog() {
    try {
        const response = await fetch(CATALOG_URL);
        if (!response.ok) {
            throw new Error('Failed to fetch catalog');
        }
        const catalog = await response.json();
        return catalog;
    } catch (error) {
        console.error('Error fetching catalog:', error);
        return null;
    }
}

// ==========================================
// Render Books
// ==========================================

function renderBooks(books, containerId, limit = null) {
    const container = document.getElementById(containerId);
    if (!container) return;

    container.innerHTML = '';

    const booksToRender = limit ? books.slice(0, limit) : books;

    if (booksToRender.length === 0) {
        container.innerHTML = `
            <div class="loading">
                <p>هیچ کتابی یافت نشد</p>
            </div>
        `;
        return;
    }

    booksToRender.forEach(book => {
        const card = createBookCard(book);
        container.appendChild(card);
    });
}

// ==========================================
// Create Book Card
// ==========================================

function createBookCard(book) {
    const card = document.createElement('div');
    card.className = 'book-card';

    const coverUrl = `${BASE_URL}/${book.cover}`;
    const fileSize = formatFileSize(book.size);
    const isNew = isBookNew(book.added_at);

    card.innerHTML = `
        <img src="${coverUrl}" alt="${book.title}" class="book-cover" loading="lazy" onerror="this.src='data:image/svg+xml,<svg xmlns=\\'http://www.w3.org/2000/svg\\' width=\\'300\\' height=\\'400\\' viewBox=\\'0 0 300 400\\'><rect fill=\\'%23FEF3C7\\' width=\\'300\\' height=\\'400\\'/><text x=\\'50%25\\' y=\\'50%25\\' dominant-baseline=\\'middle\\' text-anchor=\\'middle\\' font-family=\\'Arial\\' font-size=\\'20\\' fill=\\'%236B7280\\'>کتاب</text></svg>'">
        <div class="book-info">
            <h3 class="book-title">${book.title}</h3>
            <p class="book-author">${book.author}</p>
            <div class="book-meta">
                <span class="book-size">${fileSize}</span>
                ${isNew ? '<span class="book-badge">جدید</span>' : ''}
            </div>
        </div>
    `;

    card.addEventListener('click', () => {
        window.location.href = `book.html?id=${book.id}`;
    });

    return card;
}

// ==========================================
// Utility Functions
// ==========================================

function formatFileSize(bytes) {
    if (!bytes) return '—';

    const kb = bytes / 1024;
    const mb = kb / 1024;

    if (mb >= 1) {
        return `${mb.toFixed(1)} مگابایت`;
    } else {
        return `${kb.toFixed(0)} کیلوبایت`;
    }
}

function isBookNew(addedAt, threshold = 30) {
    if (!addedAt) return false;

    const added = new Date(addedAt);
    const now = new Date();
    const daysDiff = (now - added) / (1000 * 60 * 60 * 24);

    return daysDiff <= threshold;
}

// ==========================================
// Initialize Home Page
// ==========================================

async function initHomePage() {
    const catalog = await fetchCatalog();

    if (!catalog || !catalog.books) {
        console.error('No books in catalog');
        const container = document.getElementById('books-grid');
        if (container) {
            container.innerHTML = `
                <div class="loading">
                    <p>خطا در بارگذاری کتاب‌ها</p>
                </div>
            `;
        }
        return;
    }

    // Update book count in hero and stats
    const bookCount = catalog.books.length;
    const heroCount = document.getElementById('hero-book-count');
    const statsCount = document.getElementById('book-count');

    if (heroCount) heroCount.textContent = bookCount;
    if (statsCount) statsCount.textContent = bookCount;

    // Sort by newest first
    const sortedBooks = [...catalog.books].sort((a, b) => {
        const dateA = new Date(a.added_at || 0);
        const dateB = new Date(b.added_at || 0);
        return dateB - dateA;
    });

    // Show up to 10 latest books
    renderBooks(sortedBooks, 'books-grid', 10);
}

// ==========================================
// Page Load
// ==========================================

document.addEventListener('DOMContentLoaded', () => {
    // Check if we're on the home page
    if (document.getElementById('featured-books')) {
        initHomePage();
    }

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
});

// ==========================================
// Export for other pages
// ==========================================

window.LibraryApp = {
    fetchCatalog,
    renderBooks,
    createBookCard,
    formatFileSize,
    isBookNew
};
