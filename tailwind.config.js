module.exports = {
  mode: 'jit',
  purge: ['./pages/**/*.{js,ts,jsx,tsx}', './components/**/*.{js,ts,jsx,tsx}'],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        orange: '#d86738',
      },
      width: {
        'page-xl': '80em',
        'page-2xl': '96em',
        page: '60em',
        1: '1rem',
        2: '2rem',
        2.5: '3rem',
        3: '4rem',
        3.5: '6rem',
        4: '8rem',
        5: '16rem',
        6: '32rem',
        available: 'fill-available',
      },
      height: {
        1: '1rem',
        2: '2rem',
        2.5: '3rem',
        3: '4rem',
        3.5: '6rem',
        4: '8rem',
        4.5: '12rem',
        5: '16rem',
        6: '32rem',
      },
      maxWidth: {
        'page-xl': '80em',
        'page-2xl': '96em',
        page: '60em',
        1: '1rem',
        2: '2rem',
        2.5: '3rem',
        3: '4rem',
        4: '8rem',
        5: '16rem',
        6: '32rem',
        7: '48rem',
        8: '64rem',
        9: '96rem',
      },
      maxHeight: {
        1: '1rem',
        2: '2rem',
        2.5: '3rem',
        3: '4rem',
        4: '8rem',
        5: '16rem',
        6: '32rem',
      },
      zIndex: {
        '-10': '-10',
        navigation: 80,
        overlay: 90,
      },
      boxShadow: {
        xs: '0.5px 1px 1px rgba(2,32,33,0.5)',
        sm: '0.4px 0.8px 2px rgba(2,32,33,0.11), 0.8px 1.6px 4px rgba(2,32,33,0.11), 1.6px 3.2px 8px rgba(2,32,33,0.11), 0px 0px 0px 1px rgba(2,32,33, 0.05)',
        md: '0.4px 0.8px 2px rgba(2,32,33,0.05), 0.8px 1.6px 4px rgba(2,32,33,0.05), 1.6px 3.2px 8px rgba(2,32,33,0.05), 3.2px 6.4px 16px rgba(2,32,33,0.05), 6.4px 12.8px 32px rgba(2,32,33,0.05), 0px 0px 0px 1px rgba(2,32,33, 0.05)',
        lg: '0.4px 0.8px 2px rgba(2,32,33,0.04), 0.8px 1.6px 4px rgba(2,32,33,0.04), 1.6px 3.2px 8px rgba(2,32,33,0.04), 3.2px 6.4px 16px rgba(2,32,33,0.04), 6.4px 12.8px 32px rgba(2,32,33,0.04), 12.8px 25.6px 64px rgba(2,32,33,0.04), 25.6px 51.2px 128px rgba(2,32,33,0.04), 0px 0px 0px 1px rgba(2,32,33, 0.06)',
        secondary: '0 2px 8px 0 rgba(0, 0, 0, 0.04)',
        primary: '0 2px 8px 0 rgba(0, 0, 0, 0.16)',
        big: '0 2px 12px 0 rgba(0, 0, 0, 0.08)',
      },
      fontFamily: {
        serif:
          'Palatino Linotype, Palatino, Palladio, URW Palladio L, ui-serif, Georgia, Cambria, "Times New Roman", Times, serif',
      },
    },

    screens: {
      sm: { max: '30em' }, // small
      ns: { min: '30em' }, // not-small
      md: { min: '30em', max: '60em' }, // medium
      lg: { min: '60em' }, // large
      nl: { max: '60em' }, // not large: below-large
      xl: { min: '80em' },
      '2xl': { min: '96em' },
    },
    fontSize: {
      f1: '4rem',
      f2: '3rem',
      'f2.5': '2rem',
      f3: '1.5rem',
      f4: ['1.25rem', '1.375rem'],
      f5: ['1rem', '1.375rem'],
      f6: '0.875rem',
      f7: ['0.75rem', '1rem'],
      f8: '0.625em',
      0: 0,
    },
    spacing: {
      0: '0',
      1: '0.25rem',
      2: '0.5rem',
      2.5: '0.75rem',
      3: '1rem',
      3.5: '1.5rem',
      4: '2rem',
      4.5: '3rem',
      5: '4rem',
      6: '8rem',
      7: '16rem',
      8: '32rem',
      full: '100%',
    },
  },

  variants: {
    extend: {},
  },
  plugins: [require('@tailwindcss/typography')],
}
