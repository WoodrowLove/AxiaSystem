// theme.js
import gradients from './gradients';
import shadows from './shadows';

const theme = {
  // Colors
  colors: {
    primary: '#4F46E5', // Indigo 600
    primaryLight: '#818CF8', // Indigo 400
    primaryDark: '#3730A3', // Indigo 800
    secondary: '#EC4899', // Pink 500
    secondaryLight: '#F9A8D4', // Pink 300
    secondaryDark: '#BE185D', // Pink 700
    success: '#10B981', // Green 500
    warning: '#F59E0B', // Yellow 500
    error: '#EF4444', // Red 500
    background: '#F9FAFB', // Gray 50
    surface: '#FFFFFF', // White
    textPrimary: '#111827', // Gray 900
    textSecondary: '#6B7280', // Gray 500
    disabled: '#D1D5DB', // Gray 300
    border: '#E5E7EB', // Gray 200
    placeholder: '#9E9E9E', // Placeholder text color
    inputBackground: '#F5F5F5', // Input field background color
    error: '#D32F2F', // Error text color
  },

  // Typography
  typography: {
    fontFamily: 'System', // Defaults to system font stack
    heading: {
      fontSize: 24,
      fontWeight: '700',
      lineHeight: 32,
    },
    subheading: {
      fontSize: 20,
      fontWeight: '600',
      lineHeight: 28,
    },
    body: {
      fontSize: 16,
      fontWeight: '400',
      lineHeight: 24,
    },
    small: {
      fontSize: 14,
      fontWeight: '400',
      lineHeight: 20,
    },
    tiny: {
      fontSize: 12,
      fontWeight: '400',
      lineHeight: 16,
    },
  },

  // Spacing
  spacing: {
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 40,
  },

  // Borders
  borderRadius: {
    small: 4,
    medium: 8,
    large: 12,
    pill: 9999, // Fully rounded for pills or circular buttons
  },

  // Shadows and Gradients
  shadows,
  gradients,

  // Buttons
  buttons: {
    primary: {
      gradientColors: [theme.colors.primary, theme.colors.primaryDark],
      textColor: 'white',
      textVariant: 'subheading',
      style: {
        backgroundColor: theme.colors.primary,
      },
    },
    secondary: {
      gradientColors: [theme.colors.secondary, theme.colors.secondaryDark],
      textColor: 'black',
      textVariant: 'body',
      style: {
        backgroundColor: theme.colors.secondary,
      },
    },
    text: {
      gradientColors: [], // No gradient for text buttons
      textColor: 'primary',
      textVariant: 'body',
      style: {
        backgroundColor: 'transparent',
      },
    },

    inputs: {
        background: theme.colors.backgroundSecondary,
        borderRadius: theme.sizes.borderRadius,
        paddingVertical: 12,
        paddingHorizontal: 16,
        fontSize: 16,
      },

      // Switch
      switch: {
        primary: {
          trackOn: theme.colors.primary,
          trackOff: theme.colors.gray,
        },
        secondary: {
          trackOn: theme.colors.secondary,
          trackOff: theme.colors.lightGray,
        },
        custom: {
          trackOn: '#4CAF50',
          trackOff: '#D3D3D3',
        },
      },
      sizes: {
        switchWidth: 50,
        switchHeight: 30,
        thumbSize: 24,
        ...theme.sizes, // Keep existing sizes
      },
  },
};



export default theme;