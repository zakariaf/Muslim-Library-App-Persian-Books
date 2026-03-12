// Browse page functionality

const BASE_URL = '..';
let allBooks = [];
let currentSort = 'newest';

async function fetchCatalog() {
    try {
        const response = await fetch('../index.json');
        const catalog = await response.json();
        return catalog.books || [];
    } catch (error) {
        console.error('Error:', error);
        return [];
    }
}

function formatFileSize(bytes) {
    const mb = bytes / (1024 * 1024);
    if (mb >= 1) {
        return `${mb.toFixed(1)} مگابایت`;
    }
    const kb = bytes / 1024;
    return `${kb.toFixed(0)} کیلوبایت`;
}

function isNew(addedAt) {
    if (!addedAt) return false;
    const added = new Date(addedAt);
    const now = new Date();
    const days = (now - added) / (1000 * 60 * 60 * 24);
    return days <= 30;
}

function createBookCard(book) {
    const card = document.createElement('div');
    card.className = 'book-card';

    const coverUrl = `${BASE_URL}/${book.cover}`;
    const size = formatFileSize(book.size);
    const newBadge = isNew(book.added_at) ? '<span class="book-badge">جدید</span>' : '';

    card.innerHTML = `
        <div class="book-cover-wrapper">
            <img src="${coverUrl}" alt="${book.title}" class="book-cover" loading="lazy">
            ${newBadge}
        </div>
        <h3 class="book-title">${book.title}</h3>
        <p class="book-author">${book.author}</p>
        <div class="book-meta">
            <span class="book-size">${size}</span>
        </div>
    `;

    card.addEventListener('click', () => {
        window.location.href = `book.html?id=${book.id}`;
    });

    return card;
}

function renderBooks(books) {
    const grid = document.getElementById('books-grid');
    grid.innerHTML = '';

    if (books.length === 0) {
        grid.innerHTML = '<div class="loading">کتابی یافت نشد</div>';
        return;
    }

    books.forEach(book => {
        grid.appendChild(createBookCard(book));
    });
}

function sortBooks(books, sortType) {
    const sorted = [...books];

    switch(sortType) {
        case 'newest':
            sorted.sort((a, b) => {
                const dateA = new Date(a.added_at || 0);
                const dateB = new Date(b.added_at || 0);
                return dateB - dateA;
            });
            break;
        case 'title':
            sorted.sort((a, b) => a.title.localeCompare(b.title, 'fa'));
            break;
        case 'author':
            sorted.sort((a, b) => a.author.localeCompare(b.author, 'fa'));
            break;
    }

    return sorted;
}

function filterBooks(books, query) {
    if (!query) return books;

    const lowerQuery = query.toLowerCase();
    return books.filter(book =>
        book.title.toLowerCase().includes(lowerQuery) ||
        book.author.toLowerCase().includes(lowerQuery)
    );
}

function updateDisplay() {
    const searchQuery = document.getElementById('search-input').value;
    const filtered = filterBooks(allBooks, searchQuery);
    const sorted = sortBooks(filtered, currentSort);
    renderBooks(sorted);
}

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
    allBooks = await fetchCatalog();
    updateDisplay();

    // Search
    const searchInput = document.getElementById('search-input');
    searchInput.addEventListener('input', updateDisplay);

    // Sort buttons
    document.querySelectorAll('.sort-button').forEach(button => {
        button.addEventListener('click', () => {
            document.querySelectorAll('.sort-button').forEach(b => b.classList.remove('active'));
            button.classList.add('active');
            currentSort = button.dataset.sort;
            updateDisplay();
        });
    });
});
