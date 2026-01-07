/**
 * 1270 Logan Theme - Main JavaScript
 * 
 * Features:
 * - Header scroll effect
 * - Smooth scrolling navigation
 * - Scroll-triggered animations
 * - Gallery lightbox modal
 * - Mobile menu toggle
 */

document.addEventListener('DOMContentLoaded', function() {
  // Initialize all features
  initHeaderScroll();
  initSmoothScrolling();
  initScrollAnimations();
  initGalleryModal();
  initMobileMenu();
});

/**
 * Header scroll effect
 * Adds shadow and reduces padding when scrolled
 */
function initHeaderScroll() {
  window.addEventListener('scroll', function() {
    const header = document.getElementById('header');
    if (window.scrollY > 50) {
      header.classList.add('header-scrolled');
    } else {
      header.classList.remove('header-scrolled');
    }
  });
}

/**
 * Smooth scrolling for anchor links
 * Handles navigation to sections with offset for fixed header
 */
function initSmoothScrolling() {
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', function(e) {
      e.preventDefault();
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        window.scrollTo({
          top: target.offsetTop - 80,
          behavior: 'smooth'
        });
      }
    });
  });
}

/**
 * Scroll-triggered animations
 * Uses Intersection Observer to animate elements into view
 */
function initScrollAnimations() {
  const observerOptions = {
    root: null,
    rootMargin: '0px',
    threshold: 0.1
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('animated');
      }
    });
  }, observerOptions);

  document.querySelectorAll('.section-title, .feature-card, .detail-item, .testimonial-card').forEach((el) => {
    observer.observe(el);
  });
}

/**
 * Gallery modal functionality
 * Opens modal with full-size image when thumbnail clicked
 */
function initGalleryModal() {
  const modal = document.getElementById('imageModal');
  const modalImg = document.getElementById('modalImage');
  const closeBtn = document.getElementsByClassName('close')[0];

  // Add click event to all building gallery images
  document.querySelectorAll('.gallery-grid .gallery-item img').forEach(img => {
    img.style.cursor = 'pointer';
    img.addEventListener('click', function() {
      modal.style.display = 'block';
      // Use the full-size image from data-full attribute
      modalImg.src = this.getAttribute('data-full');
      modalImg.alt = this.alt;
    });
  });

  // Close modal when clicking X
  if (closeBtn) {
    closeBtn.onclick = function() {
      modal.style.display = 'none';
    };
  }

  // Close modal when clicking outside the image
  if (modal) {
    modal.onclick = function(event) {
      if (event.target === modal) {
        modal.style.display = 'none';
      }
    };
  }

  // Close modal with Escape key
  document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && modal.style.display === 'block') {
      modal.style.display = 'none';
    }
  });
}

/**
 * Mobile menu functionality
 * Toggles hamburger menu and handles link clicks
 */
function initMobileMenu() {
  const hamburger = document.getElementById('hamburger');
  const mobileNav = document.getElementById('mobileNav');

  if (hamburger && mobileNav) {
    hamburger.addEventListener('click', function() {
      hamburger.classList.toggle('active');
      mobileNav.classList.toggle('active');
    });

    // Close mobile menu when clicking on a link
    document.querySelectorAll('.mobile-nav a').forEach(link => {
      link.addEventListener('click', function() {
        hamburger.classList.remove('active');
        mobileNav.classList.remove('active');
      });
    });
  }
}
