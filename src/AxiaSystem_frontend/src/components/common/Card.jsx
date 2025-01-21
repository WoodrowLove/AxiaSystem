import React from 'react';
import { View, TouchableOpacity, StyleSheet, ActivityIndicator, Pressable } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import shadows from '../styles/shadows';
import theme from '../styles/theme';

/**
 * Card Component
 * 
 * @param {Object} props - Props for the card component.
 * @param {React.ReactNode} props.children - Content to render inside the card.
 * @param {boolean} props.onPress - Whether the card is pressable.
 * @param {string} props.variant - Card style variant: 'elevated', 'flat', or 'outlined'.
 * @param {Object} props.style - Additional styles to apply to the card.
 * @param {Array} props.gradientColors - Colors for the gradient background (optional).
 * @param {string} props.shadowLevel - Shadow intensity: 'none', 'light', 'medium', 'heavy'.
 * @param {React.ReactNode} props.media - Media (e.g., image or video) to render at the top of the card.
 * @param {React.ReactNode} props.actionButtons - Buttons (e.g., "Edit" or "Delete") to render at the bottom.
 * @param {boolean} props.loading - Whether to show a loading spinner.
 * @returns {JSX.Element}
 */
const Card = ({
  children,
  onPress = null,
  variant = 'elevated', // 'elevated', 'flat', 'outlined'
  style = {},
  gradientColors = null,
  shadowLevel = 'medium', // 'none', 'light', 'medium', 'heavy'
  media = null,
  actionButtons = null,
  loading = false,
}) => {
  const Wrapper = onPress ? TouchableOpacity : View;

  const getCardStyle = () => {
    switch (variant) {
      case 'outlined':
        return [styles.card, styles.outlined, style];
      case 'flat':
        return [styles.card, styles.flat, style];
      default:
        return [styles.card, styles.elevated, shadows[shadowLevel], style];
    }
  };

  return (
    <React.Fragment>
      {gradientColors ? (
        <LinearGradient
          colors={gradientColors}
          style={styles.gradientWrapper}
          start={[0, 0]}
          end={[1, 1]}
        >
          <Wrapper style={getCardStyle()} onPress={onPress} accessibilityLabel="Card" accessibilityHint="Double-tap to interact">
            {loading ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color={theme.colors.primary} />
              </View>
            ) : (
              <React.Fragment>
                {media && <View style={styles.mediaContainer}>{media}</View>}
                {children}
                {actionButtons && <View style={styles.actionButtonsContainer}>{actionButtons}</View>}
              </React.Fragment>
            )}
          </Wrapper>
        </LinearGradient>
      ) : (
        <Wrapper style={getCardStyle()} onPress={onPress} accessibilityLabel="Card" accessibilityHint="Double-tap to interact">
          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color={theme.colors.primary} />
            </View>
          ) : (
            <React.Fragment>
              {media && <View style={styles.mediaContainer}>{media}</View>}
              {children}
              {actionButtons && <View style={styles.actionButtonsContainer}>{actionButtons}</View>}
            </React.Fragment>
          )}
        </Wrapper>
      )}
    </React.Fragment>
  );
};

const styles = StyleSheet.create({
  card: {
    borderRadius: theme.borderRadius.md,
    padding: theme.spacing.md,
    backgroundColor: theme.colors.background,
    marginBottom: theme.spacing.sm,
  },
  elevated: {
    backgroundColor: theme.colors.surface,
  },
  flat: {
    backgroundColor: theme.colors.background,
    elevation: 0,
    shadowOpacity: 0,
  },
  outlined: {
    backgroundColor: theme.colors.background,
    borderWidth: 1,
    borderColor: theme.colors.border,
  },
  gradientWrapper: {
    borderRadius: theme.borderRadius.md,
    overflow: 'hidden',
  },
  loadingContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    height: 150,
  },
  mediaContainer: {
    marginBottom: theme.spacing.sm,
    borderRadius: theme.borderRadius.sm,
    overflow: 'hidden',
  },
  actionButtonsContainer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: theme.spacing.sm,
  },
});

export default Card;
