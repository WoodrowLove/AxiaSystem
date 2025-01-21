import React from 'react';
import { View, Image, Text, StyleSheet } from 'react-native';
import theme from '../styles/theme';
import shadows from '../styles/shadows';

/**
 * Avatar Component
 *
 * @param {Object} props - Props for the Avatar component.
 * @param {string} props.image - URL of the avatar image.
 * @param {string} props.initials - Initials to display if no image is provided.
 * @param {string} props.shape - Shape of the avatar: 'circle', 'square', 'rounded'.
 * @param {number} props.size - Size of the avatar (width & height).
 * @param {string} props.backgroundColor - Background color for the initials.
 * @param {Object} props.style - Additional styles for the avatar container.
 * @returns {JSX.Element}
 */
const Avatar = ({
  image,
  initials,
  shape = 'circle', // Default shape is a circle
  size = 50, // Default size is 50px
  backgroundColor = theme.colors.primary,
  style,
}) => {
  const containerStyle = [
    styles.container,
    { width: size, height: size, borderRadius: getBorderRadius(shape, size) },
    shadows.light,
    { backgroundColor },
    style,
  ];

  const textStyle = {
    fontSize: size * 0.4, // Text size relative to avatar size
    color: theme.colors.white,
  };

  return (
    <View style={containerStyle}>
      {image ? (
        <Image
          source={{ uri: image }}
          style={[styles.image, { width: size, height: size, borderRadius: getBorderRadius(shape, size) }]}
        />
      ) : (
        <Text style={[styles.initials, textStyle]}>{initials}</Text>
      )}
    </View>
  );
};

/**
 * Helper function to calculate border radius based on shape
 *
 * @param {string} shape - Shape of the avatar.
 * @param {number} size - Size of the avatar.
 * @returns {number}
 */
const getBorderRadius = (shape, size) => {
  switch (shape) {
    case 'circle':
      return size / 2;
    case 'rounded':
      return theme.sizes.borderRadius;
    case 'square':
    default:
      return 0;
  }
};

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  image: {
    resizeMode: 'cover',
  },
  initials: {
    fontFamily: theme.typography.fontFamilyBold,
    textAlign: 'center',
  },
});

export default Avatar;