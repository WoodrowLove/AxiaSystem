// gradient.js
const gradients = {
    // General gradients
    primary: {
      colors: ['#4A90E2', '#50E3C2'], // Light blue to teal
      start: { x: 0, y: 0 },
      end: { x: 1, y: 1 },
    },
    secondary: {
      colors: ['#FFC371', '#FF5F6D'], // Orange to pink
      start: { x: 0, y: 0 },
      end: { x: 1, y: 0 },
    },
  
    // Button gradients
    buttonPrimary: {
      colors: ['#6A11CB', '#2575FC'], // Purple to blue
      start: { x: 0, y: 0 },
      end: { x: 1, y: 1 },
    },
    buttonSecondary: {
      colors: ['#F7971E', '#FFD200'], // Orange to yellow
      start: { x: 0, y: 0 },
      end: { x: 1, y: 0 },
    },
  
    // Background gradients
    backgroundLight: {
      colors: ['#FFFFFF', '#F7F7F7'], // White to light gray
      start: { x: 0, y: 0 },
      end: { x: 0, y: 1 },
    },
    backgroundDark: {
      colors: ['#141E30', '#243B55'], // Dark blue tones
      start: { x: 0, y: 0 },
      end: { x: 0, y: 1 },
    },
  
    // Custom gradients for specific sections
    cardHeader: {
      colors: ['#42E695', '#3BB2B8'], // Green to teal
      start: { x: 0, y: 0 },
      end: { x: 1, y: 0 },
    },
    walletCard: {
      colors: ['#0F2027', '#203A43', '#2C5364'], // Multi-tone blue/green gradient
      start: { x: 0, y: 0 },
      end: { x: 0, y: 1 },
    },
  };
  
  export default gradients;