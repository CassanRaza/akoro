import { useCallback, useRef, useState } from 'react';
import ConfirmDialog from './ConfirmDialog';

export default function useConfirmation() {
  const [options, setOptions] = useState(null);
  const resolveConfirmation = useRef(null);

  const confirm = useCallback((nextOptions) => new Promise((resolve) => {
    if (resolveConfirmation.current) resolveConfirmation.current(false);
    resolveConfirmation.current = resolve;
    setOptions(nextOptions);
  }), []);

  const settle = useCallback((accepted) => {
    const resolve = resolveConfirmation.current;
    resolveConfirmation.current = null;
    setOptions(null);
    resolve?.(accepted);
  }, []);

  const confirmationDialog = options ? (
    <ConfirmDialog
      {...options}
      onConfirm={() => settle(true)}
      onCancel={() => settle(false)}
    />
  ) : null;

  return { confirm, confirmationDialog };
}
