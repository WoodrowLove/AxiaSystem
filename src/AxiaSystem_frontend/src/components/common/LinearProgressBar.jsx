import React from 'react';
import { View, StyleSheet, Text, Animated } from 'react-native';
import theme from '../styles/theme';

/**
 * Linear Progress Bar Component
 *
 * @param {Object} props - Props for the progress bar.
 * @param {number} props.progress - Current progress as a percentage (0-100).
 * @param {string} props.label - Optional label to display with the progress bar.
 * @param {Object} props.style - Additional styles for the container.
 * @param {Object} props.barStyle - Additional styles for the progress bar.
 * @returns {JSX.Element}
 */
const ProgressBar = ({ progress = 0, label = null, style = {}, barStyle = {} }) => {
  const animatedWidth = React.useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    Animated.timing(animatedWidth, {
      toValue: progress,
      duration: 500,
      useNativeDriver: false,
    }).start();
  }, [progress]);

  return (
    <View style={[styles.container, style]}>
      {label && <Text style={styles.label}>{label}</Text>}
      <View style={styles.barContainer}>
        <Animated.View
          style={[
            styles.bar,
            { width: `${progress}%` },
            barStyle,
            { backgroundColor: progress > 99 ? theme.colors.success : theme.colors.primary },
          ]}
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
  },
  label: {
    marginBottom: theme.spacing.sm,
    fontSize: theme.fontSizes.sm,
    color: theme.colors.text,
    textAlign: 'center',
  },
  barContainer: {
    height: theme.sizes.progressBarHeight || 10,
    backgroundColor: theme.colors.border,
    borderRadius: theme.borderRadius.md,
    overflow: 'hidden',
  },
  bar: {
    height: '100%',
    borderRadius: theme.borderRadius.md,
  },
});

export default ProgressBar;