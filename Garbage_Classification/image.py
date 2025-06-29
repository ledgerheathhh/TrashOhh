import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import transforms, datasets, models

# 定义预处理的transform
train_transform = transforms.Compose([
    transforms.RandomResizedCrop(224),
    transforms.RandomHorizontalFlip(),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# 加载训练数据集
train_dataset = datasets.ImageFolder('/Users/ledgerheath/Downloads/DataSet/TrainSet', transform=train_transform)
train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True, num_workers=4)

# 加载测试数据集
test_transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])
test_dataset = datasets.ImageFolder('/Users/ledgerheath/Downloads/DataSet/TestSet', transform=test_transform)
test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False, num_workers=4)

# 加载ResNet50模型
model = models.resnet50(pretrained=True)
# 固定预训练部分的参数，只训练新添加的分类层的参数
for param in model.parameters():
    param.requires_grad = False
num_features = model.fc.in_features
model.fc = nn.Linear(num_features, 4)

# 定义损失函数和优化器
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.fc.parameters(), lr=0.001)

# 训练模型
num_epochs = 1
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model.to(device)

if __name__ == '__main__':
    for epoch in range(num_epochs):
        train_loss, train_acc = 0.0, 0.0
        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)
            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * images.size(0)
            _, preds = torch.max(outputs, 1)
            train_acc += torch.sum(preds == labels.data)
        train_loss = train_loss / len(train_loader.dataset)
        train_acc = train_acc.double() / len(train_loader.dataset)
        print('Epoch [{}/{}], Train Loss: {:.4f}, Train Acc: {:.4f}'.format(
            epoch+1, num_epochs, train_loss, train_acc))

        # 在测试集上评估模型
        model.eval()
        test_loss, test_acc = 0.0, 0.0
        with torch.no_grad():
            for images, labels in test_loader:
                images, labels = images.to(device), labels.to(device)
                outputs = model(images)
                loss = criterion(outputs, labels)
                test_loss += loss.item() * images.size(0)
                _, preds = torch.max(outputs, 1)
                test_acc += torch.sum(preds == labels.data)
        test_loss = test_loss / len(test_loader.dataset)
        test_acc = test_acc.double() / len(test_loader.dataset)
        print('Epoch [{}/{}], Test Loss: {:.4f}, Test Acc: {:.4f}'.format(
            epoch+1, num_epochs, test_loss, test_acc))

    print(model)
    torch.save(model,'test.pth')