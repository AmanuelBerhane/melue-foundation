import { StyleSheet, View } from 'react-native';
import { ErrorToast, InfoToast, SuccessToast, type ToastConfig } from 'react-native-toast-message';

export const toastConfig: ToastConfig = {
  error: (props) => (
    <View style={styles.wrapper}>
      <ErrorToast {...props} />
    </View>
  ),
  success: (props) => (
    <View style={styles.wrapper}>
      <SuccessToast {...props} />
    </View>
  ),
  info: (props) => (
    <View style={styles.wrapper}>
      <InfoToast {...props} />
    </View>
  ),
};

const styles = StyleSheet.create({
  wrapper: {
    width: '100%',
    alignItems: 'flex-end',
    paddingRight: 16,
    paddingLeft: 40,
  },
});