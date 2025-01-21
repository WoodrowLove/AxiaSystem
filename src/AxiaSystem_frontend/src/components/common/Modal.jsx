import React from 'react';
import {
  Modal as RNModal,
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
} from 'react-native';
import theme from '../styles/theme';
import Typography from './Typography';

/**
 * Enhanced Modal Component
 *
 * @param {Object} props - Props for the Modal component.
 * @param {boolean} props.visible - Controls the visibility of the modal.
 * @param {Function} props.onClose - Callback function when the modal is closed.
 * @param {string} props.title - Title of the modal.
 * @param {React.ReactNode} props.children - Content of the modal.
 * @param {React.ReactNode} props.header - Custom header content.
 * @param {React.ReactNode} props.footer - Custom footer content.
 * @param {Object} props.style - Additional styles for the modal container.
 * @param {Object} props.overlayStyle - Additional styles for the overlay.
 * @param {string} props.animationType - Animation type: 'fade', 'slide', or 'none'.
 * @param {Array} props.actions - Array of action buttons (e.g., [{ text: 'Confirm', onPress: () => {} }]).
 * @returns {JSX.Element}
 */
const Modal = ({
  visible,
  onClose,
  title,
  children,
  header,
  footer,
  style = {},
  overlayStyle = {},
  animationType = 'fade',
  actions = [],
}) => {
  return (
    <RNModal
      transparent
      visible={visible}
      animationType={animationType}
      onRequestClose={onClose}
      accessible
    >
      <View style={[styles.overlay, overlayStyle]}>
        <View style={[styles.modalContainer, style]}>
          {/* Header Section */}
          {header ? (
            <View style={styles.header}>{header}</View>
          ) : (
            title && <Typography variant="title" style={styles.title}>{title}</Typography>
          )}

          {/* Content Section */}
          <View style={styles.content}>{children}</View>

          {/* Footer or Action Buttons */}
          {footer ? (
            <View style={styles.footer}>{footer}</View>
          ) : (
            <View style={styles.actionContainer}>
              {actions.map((action, index) => (
                <TouchableOpacity
                  key={index}
                  onPress={action.onPress}
                  style={[
                    styles.actionButton,
                    action.type === 'secondary' && styles.secondaryButton,
                  ]}
                >
                  <Typography
                    variant="button"
                    color={
                      action.type === 'secondary'
                        ? theme.colors.primary
                        : theme.colors.background
                    }
                  >
                    {action.text}
                  </Typography>
                </TouchableOpacity>
              ))}
              <TouchableOpacity
                onPress={onClose}
                style={styles.actionButton}
              >
                <Typography variant="button" color={theme.colors.background}>
                  Close
                </Typography>
              </TouchableOpacity>
            </View>
          )}
        </View>
      </View>
    </RNModal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContainer: {
    width: '85%',
    padding: 20,
    backgroundColor: theme.colors.background,
    borderRadius: theme.sizes.borderRadius,
    elevation: 5,
    shadowColor: theme.colors.shadow,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
  },
  header: {
    marginBottom: 16,
  },
  title: {
    fontSize: theme.typography.titleFontSize,
    fontWeight: theme.typography.fontWeightBold,
    marginBottom: 10,
    color: theme.colors.text,
  },
  content: {
    marginBottom: 20,
  },
  actionContainer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: 10,
  },
  actionButton: {
    backgroundColor: theme.colors.primary,
    paddingVertical: 10,
    paddingHorizontal: 15,
    borderRadius: theme.sizes.borderRadius,
    marginLeft: 10,
  },
  secondaryButton: {
    backgroundColor: 'transparent',
    borderWidth: 1,
    borderColor: theme.colors.primary,
  },
  footer: {
    marginTop: 10,
  },
});

export default Modal;