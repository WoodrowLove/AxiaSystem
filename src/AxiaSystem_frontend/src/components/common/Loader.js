import React from 'react';
import { ActivityIndicator, View, StyleSheet, Text } from 'react-native';
import theme from '../styles/theme';
import Typography from './Typography';

/**
 * Loader Component
 *
 * @param {Object} props - Props for the Loader component.
 * @param {string} props.size - Size of the loader ('small', 'large', or a numeric value for custom size).
 * @param {string} props.color - Color of the loader.
 * @param {string} props.label - Optional label text below the spinner.
 * @param {Object} props.style - Additional styles for the loader container.
 * @param {boolean} props.overlay - Whether to display the loader with an overlay background.
 * @returns {JSX.Element}
 */
const Loader = ({
  size = 'small', // Default size
  color = theme.colors.primary, // Default color
  label, // Optional label text
  style, // Additional styles for the loader container
  overlay = false, // Overlay background toggle
}) => {
  const loaderStyle = [
    styles.container,
    overlay && styles.overlay, // Apply overlay style if enabled
    style,
  ];

  return (
    <View style={loaderStyle}>
      <ActivityIndicator size={size} color={color} />
      {label && (
        <Typography variant="caption" color={theme.colors.text} style={styles.label}>
          {label}
        </Typography>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    zIndex: 999,
  },
  label: {
    marginTop: 8,
    textAlign: 'center',
  },
});

export default Loader;