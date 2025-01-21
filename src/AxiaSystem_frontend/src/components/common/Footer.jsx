import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import theme from '../styles/theme';
import shadows from '../styles/shadows';

/**
 * Footer Component
 *
 * @param {Object} props - Props for the footer component.
 * @param {React.ReactNode} props.leftAction - Component for the left action (e.g., a back button).
 * @param {React.ReactNode} props.centerContent - Content for the center of the footer (e.g., navigation text).
 * @param {React.ReactNode} props.rightAction - Component for the right action (e.g., a next button).
 * @param {Array} props.gradientColors - Gradient colors for the background.
 * @param {Object} props.style - Additional styles for the footer.
 * @param {boolean} props.elevated - Whether the footer has shadow/elevation.
 * @param {boolean} props.visible - Controls the visibility of the footer.
 * @param {number} props.shadowLevel - Controls the shadow intensity (default: 'medium').
 * @param {boolean} props.showDivider - Whether to show a divider above the footer.
 * @param {Object} props.textStyle - Additional styles for the center text.
 * @returns {JSX.Element}
 */
const Footer = ({
  leftAction = null,
  centerContent = null,
  rightAction = null,
  gradientColors = null,
  style = {},
  elevated = true,
  visible = true,
  shadowLevel = 'medium',
  showDivider = false,
  textStyle = {},
}) => {
  if (!visible) return null;

  return (
    <React.Fragment>
      {showDivider && <View style={styles.divider} />}
      {gradientColors ? (
        <LinearGradient
          colors={gradientColors}
          style={[styles.container, elevated && shadows[shadowLevel], style]}
          start={[0, 0]}
          end={[1, 1]}
        >
          <View style={styles.innerContainer}>
            {leftAction && (
              <TouchableOpacity
                style={styles.actionWrapper}
                accessibilityLabel="Left Action"
                onPress={leftAction.onPress}
              >
                {leftAction.icon}
              </TouchableOpacity>
            )}
            {centerContent && (
              <View style={styles.centerWrapper}>
                <Text style={[styles.text, textStyle]}>{centerContent}</Text>
              </View>
            )}
            {rightAction && (
              <TouchableOpacity
                style={styles.actionWrapper}
                accessibilityLabel="Right Action"
                onPress={rightAction.onPress}
              >
                {rightAction.icon}
              </TouchableOpacity>
            )}
          </View>
        </LinearGradient>
      ) : (
        <View style={[styles.container, elevated && shadows[shadowLevel], style]}>
          <View style={styles.innerContainer}>
            {leftAction && (
              <TouchableOpacity
                style={styles.actionWrapper}
                accessibilityLabel="Left Action"
                onPress={leftAction.onPress}
              >
                {leftAction.icon}
              </TouchableOpacity>
            )}
            {centerContent && (
              <View style={styles.centerWrapper}>
                <Text style={[styles.text, textStyle]}>{centerContent}</Text>
              </View>
            )}
            {rightAction && (
              <TouchableOpacity
                style={styles.actionWrapper}
                accessibilityLabel="Right Action"
                onPress={rightAction.onPress}
              >
                {rightAction.icon}
              </TouchableOpacity>
            )}
          </View>
        </View>
      )}
    </React.Fragment>
  );
};

const styles = StyleSheet.create({
  container: {
    height: 60,
    paddingHorizontal: theme.spacing.md,
    backgroundColor: theme.colors.surface,
    justifyContent: 'center',
    borderTopLeftRadius: theme.borderRadius.sm,
    borderTopRightRadius: theme.borderRadius.sm,
  },
  innerContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  actionWrapper: {
    padding: theme.spacing.sm,
  },
  centerWrapper: {
    flex: 1,
    alignItems: 'center',
  },
  text: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.onSurface,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: theme.colors.divider,
  },
});

export default Footer;