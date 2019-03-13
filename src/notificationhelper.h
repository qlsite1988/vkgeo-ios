#ifndef NOTIFICATIONHELPER_H
#define NOTIFICATIONHELPER_H

#include <QtCore/QObject>
#include <QtCore/QString>

class NotificationHelper : public QObject
{
    Q_OBJECT

public:
    explicit NotificationHelper(QObject *parent = nullptr);
    ~NotificationHelper() override = default;

    Q_INVOKABLE void showNotification(const QString &id, const QString &title, const QString &body);
    Q_INVOKABLE void hideNotification(const QString &id);
};

#endif // NOTIFICATIONHELPER_H
