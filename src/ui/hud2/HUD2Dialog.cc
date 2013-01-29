#include "HUD2.h"

#include "HUD2Dialog.h"
#include "ui_HUD2Dialog.h"

HUD2Dialog::HUD2Dialog(QWidget *parent) :
    QDialog(parent),
    ui(new Ui::HUD2Dialog)
{
    ui->setupUi(this);
    connect(ui->AAcheckBox, SIGNAL(clicked(bool)), parent, SLOT(toggleAntialising(bool)));
    connect(ui->renderComboBox, SIGNAL(activated(int)), parent, SLOT(switchRender(int)));
    ui->fpsSpinBox->setRange(1, 100);
    connect(ui->fpsSpinBox, SIGNAL(valueChanged(int)), parent, SLOT(setFpsLimit(int)));
}

HUD2Dialog::~HUD2Dialog()
{
    delete ui;
}
