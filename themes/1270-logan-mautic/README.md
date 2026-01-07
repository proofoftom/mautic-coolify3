# 1270 Logan Victorian Mautic Theme

A Victorian-styled page theme for Mautic featuring a luxury apartment property design with hero section, feature cards, image gallery with lightbox, and responsive navigation.

## Features

- **Victorian Aesthetic**: Distinctive burgundy/gold/cream color palette with Playfair Display + Montserrat typography
- **Responsive Design**: Mobile-first approach with breakpoints at 768px and 480px
- **Interactive Gallery**: 16-image grid with lightbox modal functionality
- **Smooth Animations**: Intersection Observer for scroll-triggered fade-in effects
- **Modular CSS**: 6 organized CSS files for maintainability
- **Twig Templates**: Component-based partials for easy customization

## Installation

1. Copy the entire `1270-logan-mautic` folder to your Mautic `themes/` directory
2. The theme will automatically appear in Mautic's theme selector
3. Select "1270 Logan Victorian" when creating a new landing page

## Theme Structure

```
themes/1270-logan-mautic/
├── config.json              # Theme metadata and configuration
├── README.md                # This documentation file
├── thumbnail.png            # Theme preview image (300x200px recommended)
├── html/                    # Twig templates
│   ├── base.html.twig       # Base HTML document structure
│   ├── page.html.twig       # Main page template
│   └── partials/            # Reusable components
│       ├── _header.html.twig
│       ├── _mobile-nav.html.twig
│       ├── _hero.html.twig
│       ├── _location.html.twig
│       ├── _building.html.twig
│       ├── _gallery.html.twig
│       ├── _cta.html.twig
│       ├── _footer.html.twig
│       └── _modal.html.twig
├── css/                     # Stylesheets
│   ├── variables.css        # CSS custom properties
│   ├── base.css             # Reset and typography
│   ├── components.css       # Reusable component styles
│   ├── layout.css           # Grid and structure
│   ├── sections.css         # Section-specific styles
│   └── responsive.css       # Media queries
├── js/                      # JavaScript
│   └── main.js             # All interactions
└── images/                  # Static assets
    ├── building-01.webp
    ├── hero_1U0A9837.webp
    ├── hero_1U0A9837_thumb.webp
    └── [16 gallery images]
```

## Customization

### Colors

Edit [`css/variables.css`](css/variables.css) to customize the color palette:

```css
:root {
  --deep-burgundy: #5d2e3f;   /* Primary brand color */
  --gold: #c9a66b;            /* Accent/CTA color */
  --cream: #f5f0e6;           /* Background */
  --dark-green: #2e5d3f;      /* Secondary accent */
  --warm-gray: #8c8573;       /* Muted text */
  --victorian-blue: #3a506b;  /* Tertiary accent */
}
```

### Typography

Fonts are loaded from Google Fonts:
- **Headings**: Playfair Display (weights 400, 700, 900)
- **Body**: Montserrat (weights 300, 400, 500, 600, 700)

### Content

Edit the partial templates in [`html/partials/`](html/partials/) to customize content:
- [`_header.html.twig`](html/partials/_header.html.twig) - Navigation links and logo
- [`_hero.html.twig`](html/partials/_hero.html.twig) - Hero title, subtitle, and CTA
- [`_location.html.twig`](html/partials/_location.html.twig) - Feature cards (7 items)
- [`_building.html.twig`](html/partials/_building.html.twig) - Building details and amenities
- [`_gallery.html.twig`](html/partials/_gallery.html.twig) - Image gallery (16 images)
- [`_cta.html.twig`](html/partials/_cta.html.twig) - Call-to-action section
- [`_footer.html.twig`](html/partials/_footer.html.twig) - Footer content

### Images

Replace images in the [`images/`](images/) directory:
- `building-01.webp` - Hero background
- `hero_1U0A9837.webp` - Building exterior
- Gallery images: `1U0A0008.webp` through `1U0A9982.webp`
- Corresponding thumbnails: `*_thumb.webp` versions

## Mautic Integration

### Form Integration

To embed a Mautic form in the CTA section, edit [`_cta.html.twig`](html/partials/_cta.html.twig):

```twig
{% if form is defined %}
    {{ form|raw }}
{% else %}
    <a href="{{ cta_url }}" class="btn">{{ cta_text }}</a>
{% endif %}
```

### Tracking Code

The theme automatically includes Mautic's tracking pixel via the `mauticContent()` function in [`base.html.twig`](html/base.html.twig).

### Asset URLs

Use Mautic's `getAssetUrl()` helper for all asset references:

```twig
{{ getAssetUrl('themes/1270-logan-mautic/images/building-01.webp') }}
```

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)

## External Dependencies

- Font Awesome 6.4.0 (CDN)
- Google Fonts API

## License

This theme is provided as-is for use with Mautic. Modify and distribute freely for your projects.

## Credits

Based on the 1270 Logan St property website design.
Original template: [`themes/1270-logan/index.html`](../1270-logan/index.html)
