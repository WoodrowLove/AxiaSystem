import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import theme from '../styles/theme';
import shadows from '../styles/shadows';

/**
 * Header Component
 *
 * @param {Object} props - Props for the header component.
 * @param {string} props.title - The title to display in the header.
 * @param {React.ReactNode} props.leftIcon - Component to display on the left (e.g., back button).
 * @param {React.ReactNode} props.rightIcon - Component to display on the right (e.g., menu, notifications).
 * @param {Array} props.gradientColors - Gradient colors for the background.
 * @param {Object} props.style - Additional styles for the header.
 * @param {boolean} props.elevated - Whether the header has shadow/elevation.
 * @returns {JSX.Element}
 */
const Header = ({
  title = '',
  leftIcon = null,
  rightIcon = null,
  gradientColors = null,
  style = {},
  elevated = true,
}) => {
  return gradientColors ? (
    <LinearGradient
      colors={gradientColors}
      style={[styles.container, elevated && shadows.medium, style]}
      start={[0, 0]}
      end={[1, 1]}
    >
      <View style={styles.innerContainer}>
        {leftIcon && <TouchableOpacity style={styles.iconWrapper}>{leftIcon}</TouchableOpacity>}
        <Text style={styles.title}>{title}</Text>
        {rightIcon && <TouchableOpacity style={styles.iconWrapper}>{rightIcon}</TouchableOpacity>}
      </View>
    </LinearGradient>
  ) : (
    <View style={[styles.container, elevated && shadows.medium, style]}>
      <View style={styles.innerContainer}>
        {leftIcon && <TouchableOpacity style={styles.iconWrapper}>{leftIcon}</TouchableOpacity>}
        <Text style={styles.title}>{title}</Text>
        {rightIcon && <TouchableOpacity style={styles.iconWrapper}>{rightIcon}</TouchableOpacity>}
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    height: 60,
    paddingHorizontal: theme.spacing.md,
    backgroundColor: theme.colors.surface,
    justifyContent: 'center',
    borderBottomLeftRadius: theme.borderRadius.sm,
    borderBottomRightRadius: theme.borderRadius.sm,
  },
  innerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  title: {
    fontSize: theme.fontSizes.lg,
    fontWeight: 'bold',
    color: theme.colors.onSurface,
  },
  iconWrapper: {
    padding: theme.spacing.sm,
  },
});

export default Header;